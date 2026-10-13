import logging
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status

from services import extractor, scorer
from services.firebase import get_firestore_client, get_storage_bucket
from services.pdf_generator import generate_topic_pdf
from utils import tokens as tokens_util

log = logging.getLogger(__name__)


async def validate_note(
    user_id: str,
    uploader_name: str,
    title: str,
    subject: str,
    topic: str,
    file_urls: list[str],
) -> dict:
    # 1 — verify topic exists in model
    valid_pairs = {(t["subject"], t["topic"]) for t in scorer.get_topics()}
    if (subject, topic) not in valid_pairs:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Topic '{topic}' under subject '{subject}' not found. Call GET /anie/topics.",
        )

    # 2 — download files and extract text
    note_text = await extractor.extract_all(file_urls)
    if not note_text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No text could be extracted from the uploaded files.",
        )

    word_count = len(note_text.split())
    warning    = None
    if word_count < 50:
        warning = f"Note is very short ({word_count} words) — score may be less reliable."

    # 3 — score using trained model
    result = scorer.score_note(note_text, subject, topic)

    # 4 — token and approval logic
    tokens_earned, is_approved, rejection_reason = tokens_util.calculate(
        result["score"], result["semantic_score"], result["keyword_score"]
    )

    # 5 — save pending note to Firestore
    note_id = str(uuid.uuid4())
    db      = get_firestore_client()

    note_doc = {
        "note_id":          note_id,
        "title":            title,
        "subject":          subject,
        "topic":            topic,
        "original_urls":    file_urls,
        "uploader_id":      user_id,
        "uploader_name":    uploader_name,
        "score":            result["score"],
        "level":            result["level"],
        "level_confidence": result["level_confidence"],
        "semantic_score":   result["semantic_score"],
        "keyword_score":    result["keyword_score"],
        "keywords_found":   result["keywords_found"],
        "note_word_count":  word_count,
        "extracted_text":   note_text,
        "is_published":     False,
        "topic_pdf_url":    None,
        "tokens_earned":    tokens_earned if is_approved else 0,
        "rejection_reason": rejection_reason,
        "download_count":   0,
        "like_count":       0,
        "comment_count":    0,
        "liked_by":         [],
        "status":           "pending_publish" if is_approved else "rejected",
        "created_at":       datetime.now(timezone.utc),
    }

    db.collection("notes").document(note_id).set(note_doc)

    log.info(
        f"Note {note_id} by {user_id} — score={result['score']} "
        f"level={result['level']} approved={is_approved}"
    )

    return {
        "note_id":          note_id,
        "score":            result["score"],
        "level":            result["level"],
        "level_confidence": result["level_confidence"],
        "is_approved":      is_approved,
        "tokens_earned":    tokens_earned if is_approved else 0,
        "rejection_reason": rejection_reason,
        "word_count":       word_count,
        "keywords_found":   result["keywords_found"],
        "warning":          warning,
    }


async def publish_note(note_id: str, user_id: str) -> dict:
    db       = get_firestore_client()
    note_ref = db.collection("notes").document(note_id)
    note_doc = note_ref.get()

    if not note_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found.")

    note = note_doc.to_dict()

    if note["uploader_id"] != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your note.")

    if note["status"] == "rejected":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rejected notes cannot be published.",
        )

    if note["is_published"]:
        return {
            "note_id":      note_id,
            "topic_pdf_url": note.get("topic_pdf_url"),
            "tokens_earned": note.get("tokens_earned", 0),
        }

    # generate topic PDF from the already-extracted text
    pdf_bytes = generate_topic_pdf(
        subject          = note["subject"],
        topic            = note["topic"],
        score            = note["score"],
        level            = note["level"],
        level_confidence = note["level_confidence"],
        semantic_score   = note["semantic_score"],
        keyword_score    = note["keyword_score"],
        keywords_found   = note.get("keywords_found", []),
        keywords_missed  = [],
        note_text        = note["extracted_text"],
    )

    # upload PDF to Firebase Storage
    bucket      = get_storage_bucket()
    blob_path   = f"topic_pdfs/{note_id}/topics.pdf"
    blob        = bucket.blob(blob_path)
    blob.upload_from_string(pdf_bytes, content_type="application/pdf")
    blob.make_public()
    topic_pdf_url = blob.public_url

    tokens_earned = note.get("tokens_earned", 0)

    # update note record
    note_ref.update({
        "is_published":  True,
        "topic_pdf_url": topic_pdf_url,
        "status":        "published",
        "published_at":  datetime.now(timezone.utc),
    })

    # update user's uploaded_notes list
    db.collection("users").document(user_id).update({
        "uploaded_notes": _firestore_array_union([note_id])
    })

    # update token wallet
    wallet_ref = db.collection("wallets").document(user_id)
    wallet     = wallet_ref.get()
    if wallet.exists:
        wallet_ref.update({"balance": _firestore_increment(tokens_earned)})
    else:
        wallet_ref.set({"user_id": user_id, "balance": tokens_earned, "updated_at": datetime.now(timezone.utc)})

    # log token transaction
    if tokens_earned > 0:
        db.collection("token_transactions").add({
            "user_id":   user_id,
            "type":      "earn",
            "amount":    tokens_earned,
            "reason":    f"Note published — score {note['score']} ({note['level']})",
            "note_id":   note_id,
            "timestamp": datetime.now(timezone.utc),
        })

    log.info(f"Note {note_id} published — PDF uploaded — {tokens_earned} tokens awarded to {user_id}")

    return {
        "note_id":       note_id,
        "topic_pdf_url": topic_pdf_url,
        "tokens_earned": tokens_earned,
    }


def _get_uploader_photo_url(db, uploader_id: str, cache: dict) -> str | None:
    if uploader_id in cache:
        return cache[uploader_id]

    user_doc  = db.collection("users").document(uploader_id).get()
    photo_url = user_doc.to_dict().get("photo_url") if user_doc.exists else None
    cache[uploader_id] = photo_url
    return photo_url


def list_published_notes(
    subject: str | None = None,
    topic: str | None = None,
    viewer_id: str | None = None,
) -> list[dict]:
    db    = get_firestore_client()
    query = db.collection("notes").where("is_published", "==", True)

    if subject:
        query = query.where("subject", "==", subject)
    if topic:
        query = query.where("topic", "==", topic)

    docs = query.limit(50).stream()

    results       = []
    photo_cache: dict = {}
    for doc in docs:
        d = doc.to_dict()
        liked_by     = d.get("liked_by", [])
        purchased_by = d.get("purchased_by", [])
        has_access   = bool(viewer_id) and (
            viewer_id == d["uploader_id"] or viewer_id in purchased_by
        )
        results.append({
            "note_id":           d["note_id"],
            "title":             d["title"],
            "subject":           d["subject"],
            "topic":             d["topic"],
            "score":             d["score"],
            "level":             d["level"],
            "uploader_id":       d["uploader_id"],
            "uploader_name":     d.get("uploader_name", "Anonymous"),
            "uploader_photo_url": _get_uploader_photo_url(db, d["uploader_id"], photo_cache),
            "topic_pdf_url":     d.get("topic_pdf_url") if has_access else None,
            "download_count":    d.get("download_count", 0),
            "like_count":        d.get("like_count", 0),
            "comment_count":     d.get("comment_count", 0),
            "liked_by_me":       bool(viewer_id) and viewer_id in liked_by,
            "purchased_by_me":   has_access,
            "created_at":        d["created_at"].isoformat() if hasattr(d["created_at"], "isoformat") else str(d["created_at"]),
        })
    return sorted(results, key=lambda x: x["score"], reverse=True)


def get_note_detail(note_id: str, viewer_id: str | None = None) -> dict:
    db       = get_firestore_client()
    note_ref = db.collection("notes").document(note_id)
    note_doc = note_ref.get()

    if not note_doc.exists or not note_doc.to_dict().get("is_published"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found.")

    d            = note_doc.to_dict()
    liked_by     = d.get("liked_by", [])
    purchased_by = d.get("purchased_by", [])
    has_access   = bool(viewer_id) and (
        viewer_id == d["uploader_id"] or viewer_id in purchased_by
    )
    return {
        "note_id":         d["note_id"],
        "title":           d["title"],
        "subject":         d["subject"],
        "topic":           d["topic"],
        "score":           d["score"],
        "level":           d["level"],
        "uploader_id":     d["uploader_id"],
        "uploader_name":   d.get("uploader_name", "Anonymous"),
        "uploader_photo_url": _get_uploader_photo_url(db, d["uploader_id"], {}),
        "topic_pdf_url":   d.get("topic_pdf_url") if has_access else None,
        "download_count":  d.get("download_count", 0),
        "like_count":      d.get("like_count", 0),
        "comment_count":   d.get("comment_count", 0),
        "liked_by_me":     bool(viewer_id) and viewer_id in liked_by,
        "purchased_by_me": has_access,
        "created_at":      d["created_at"].isoformat() if hasattr(d["created_at"], "isoformat") else str(d["created_at"]),
        "extracted_text":  d.get("extracted_text", "") if has_access else "",
        "note_word_count": d.get("note_word_count", 0),
        "original_urls":   d.get("original_urls", []) if has_access else [],
    }


def purchase_note(note_id: str, user_id: str) -> dict:
    """Unlocks a note's PDF/content for [user_id], spending 1 token unless
    they're the uploader or already purchased it (both are free/idempotent —
    a purchase is a lifetime unlock, never charged twice).
    """
    from google.cloud import firestore

    db       = get_firestore_client()
    note_ref = db.collection("notes").document(note_id)
    note_doc = note_ref.get()

    if not note_doc.exists or not note_doc.to_dict().get("is_published"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found.")

    note         = note_doc.to_dict()
    purchased_by = note.get("purchased_by", [])
    wallet_ref   = db.collection("wallets").document(user_id)

    if note["uploader_id"] == user_id or user_id in purchased_by:
        wallet_doc = wallet_ref.get()
        balance    = wallet_doc.to_dict().get("balance", 0) if wallet_doc.exists else 0
        return {
            "note_id":       note_id,
            "purchased":     True,
            "balance":       balance,
            "topic_pdf_url": note.get("topic_pdf_url"),
        }

    user_ref    = db.collection("users").document(user_id)
    transaction = db.transaction()

    @firestore.transactional
    def _run(transaction):
        wallet_snapshot = wallet_ref.get(transaction=transaction)
        balance = wallet_snapshot.to_dict().get("balance", 0) if wallet_snapshot.exists else 0

        if balance < 1:
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail="Not enough tokens to unlock this note.",
            )

        new_balance = balance - 1
        if wallet_snapshot.exists:
            transaction.update(wallet_ref, {"balance": _firestore_increment(-1)})
        else:
            transaction.set(wallet_ref, {
                "user_id":    user_id,
                "balance":    new_balance,
                "updated_at": datetime.now(timezone.utc),
            })

        transaction.update(note_ref, {"purchased_by": _firestore_array_union([user_id])})
        transaction.set(
            user_ref,
            {"purchased_notes": _firestore_array_union([note_id])},
            merge=True,
        )
        return new_balance

    new_balance = _run(transaction)

    db.collection("token_transactions").add({
        "user_id":   user_id,
        "type":      "spend",
        "amount":    -1,
        "reason":    f"Unlocked note '{note.get('title')}'",
        "note_id":   note_id,
        "timestamp": datetime.now(timezone.utc),
    })

    log.info(f"Note {note_id} purchased by {user_id} — 1 token spent, balance now {new_balance}")

    return {
        "note_id":       note_id,
        "purchased":     True,
        "balance":       new_balance,
        "topic_pdf_url": note.get("topic_pdf_url"),
    }


def increment_download(note_id: str) -> dict:
    db       = get_firestore_client()
    note_ref = db.collection("notes").document(note_id)
    note_doc = note_ref.get()

    if not note_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found.")

    note_ref.update({"download_count": _firestore_increment(1)})
    updated_count = note_doc.to_dict().get("download_count", 0) + 1
    return {"download_count": updated_count}


def get_wallet_balance(user_id: str) -> dict:
    db         = get_firestore_client()
    wallet_doc = db.collection("wallets").document(user_id).get()
    balance    = wallet_doc.to_dict().get("balance", 0) if wallet_doc.exists else 0
    return {"balance": balance}


def toggle_like(note_id: str, user_id: str) -> dict:
    from google.cloud import firestore

    db       = get_firestore_client()
    note_ref = db.collection("notes").document(note_id)

    if not note_ref.get().exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found.")

    transaction = db.transaction()

    @firestore.transactional
    def _run(transaction):
        snapshot = note_ref.get(transaction=transaction)
        data          = snapshot.to_dict()
        liked_by      = data.get("liked_by", [])
        current_count = data.get("like_count", 0)

        if user_id in liked_by:
            transaction.update(note_ref, {
                "liked_by":   _firestore_array_remove([user_id]),
                "like_count": _firestore_increment(-1),
            })
            return {"liked": False, "like_count": max(current_count - 1, 0)}

        transaction.update(note_ref, {
            "liked_by":   _firestore_array_union([user_id]),
            "like_count": _firestore_increment(1),
        })
        return {"liked": True, "like_count": current_count + 1}

    return _run(transaction)


def list_comments(note_id: str) -> list[dict]:
    db       = get_firestore_client()
    note_ref = db.collection("notes").document(note_id)
    docs     = note_ref.collection("comments").order_by("created_at").stream()

    results = []
    for doc in docs:
        d = doc.to_dict()
        results.append({
            "comment_id": d["comment_id"],
            "user_id":    d["user_id"],
            "user_name":  d.get("user_name", "Anonymous"),
            "text":       d["text"],
            "created_at": d["created_at"].isoformat() if hasattr(d["created_at"], "isoformat") else str(d["created_at"]),
        })
    return results


def add_comment(note_id: str, user_id: str, user_name: str, text: str) -> dict:
    db       = get_firestore_client()
    note_ref = db.collection("notes").document(note_id)

    if not note_ref.get().exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found.")

    comment_id  = str(uuid.uuid4())
    created_at  = datetime.now(timezone.utc)
    comment_doc = {
        "comment_id": comment_id,
        "user_id":    user_id,
        "user_name":  user_name,
        "text":       text,
        "created_at": created_at,
    }
    note_ref.collection("comments").document(comment_id).set(comment_doc)
    note_ref.update({"comment_count": _firestore_increment(1)})

    return {
        "comment_id": comment_id,
        "user_id":    user_id,
        "user_name":  user_name,
        "text":       text,
        "created_at": created_at.isoformat(),
    }


# ── Firestore sentinel helpers ────────────────────────────────────────────────

def _firestore_array_union(items: list):
    from google.cloud.firestore_v1 import ArrayUnion
    return ArrayUnion(items)


def _firestore_array_remove(items: list):
    from google.cloud.firestore_v1 import ArrayRemove
    return ArrayRemove(items)


def _firestore_increment(value: int):
    from google.cloud.firestore_v1 import Increment
    return Increment(value)
