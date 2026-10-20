from datetime import datetime, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client

_FEEDBACK = "grocery_feedback"
_CHATS = "grocery_chats"


def submit_feedback(from_uid: str, chat_id: str, rating: int, comment: str) -> dict:
    db = get_firestore_client()

    chat_doc = db.collection(_CHATS).document(chat_id).get()
    if not chat_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found.")
    chat = chat_doc.to_dict()

    shopper_id = chat.get("shopper_id")
    requester_id = chat.get("requester_id")
    if from_uid not in (shopper_id, requester_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not a member of this chat.")

    if chat.get("payment_status") != "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Feedback can only be submitted after the transaction is complete.",
        )

    existing = db.collection(_FEEDBACK).where("from_user_id", "==", from_uid).get()
    for doc in existing:
        if doc.to_dict().get("chat_id") == chat_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already submitted feedback for this chat.",
            )

    to_uid = requester_id if from_uid == shopper_id else shopper_id
    to_role = "requester" if from_uid == shopper_id else "shopper"

    now = datetime.now(timezone.utc)
    ref = db.collection(_FEEDBACK).document()
    data = {
        "id": ref.id,
        "from_user_id": from_uid,
        "to_user_id": to_uid,
        "chat_id": chat_id,
        "rating": rating,
        "comment": comment.strip(),
        "to_user_role": to_role,
        "created_at": now,
    }
    ref.set(data)
    return _serialize(data)


def get_trust_profile(uid: str) -> dict:
    db = get_firestore_client()
    docs = db.collection(_FEEDBACK).where("to_user_id", "==", uid).get()

    all_ratings: list[dict] = []
    shopper_scores: list[int] = []
    requester_scores: list[int] = []

    for doc in docs:
        d = doc.to_dict()
        created = d.get("created_at")
        role = d.get("to_user_role", "")
        rating = d.get("rating", 0)
        entry = {
            "rating": rating,
            "comment": d.get("comment", ""),
            "created_at": created.isoformat() if hasattr(created, "isoformat") else str(created or ""),
        }
        all_ratings.append(entry)
        if role == "shopper":
            shopper_scores.append(rating)
        elif role == "requester":
            requester_scores.append(rating)

    all_ratings.sort(key=lambda x: x["created_at"], reverse=True)

    total = len(all_ratings)
    avg = round(sum(r["rating"] for r in all_ratings) / total, 2) if total > 0 else 0.0

    shopper_count = len(shopper_scores)
    shopper_avg = round(sum(shopper_scores) / shopper_count, 2) if shopper_count > 0 else 0.0

    requester_count = len(requester_scores)
    requester_avg = round(sum(requester_scores) / requester_count, 2) if requester_count > 0 else 0.0

    # Completed trips — filter in Python to avoid composite index requirement
    as_shopper_docs = db.collection(_CHATS).where("shopper_id", "==", uid).get()
    as_requester_docs = db.collection(_CHATS).where("requester_id", "==", uid).get()
    completed_trips = (
        sum(1 for d in as_shopper_docs if d.to_dict().get("payment_status") == "completed")
        + sum(1 for d in as_requester_docs if d.to_dict().get("payment_status") == "completed")
    )

    badges = _compute_badges(
        shopper_avg=shopper_avg,
        shopper_count=shopper_count,
        requester_avg=requester_avg,
        requester_count=requester_count,
        completed_trips=completed_trips,
        avg_rating=avg,
        total_ratings=total,
    )

    return {
        "uid": uid,
        "avg_rating": avg,
        "total_ratings": total,
        "shopper_avg": shopper_avg,
        "shopper_count": shopper_count,
        "requester_avg": requester_avg,
        "requester_count": requester_count,
        "completed_trips": completed_trips,
        "badges": badges,
        "recent_ratings": all_ratings[:10],
    }


def _compute_badges(
    shopper_avg: float,
    shopper_count: int,
    requester_avg: float,
    requester_count: int,
    completed_trips: int,
    avg_rating: float,
    total_ratings: int,
) -> list[str]:
    badges = []
    if shopper_count >= 5 and shopper_avg >= 4.5:
        badges.append("reliable_shopper")
    if requester_count >= 3 and requester_avg >= 4.0:
        badges.append("trusted_payer")
    if completed_trips >= 10:
        badges.append("community_helper")
    if total_ratings >= 5 and avg_rating >= 4.8:
        badges.append("top_rated")
    return badges


def has_submitted_feedback(from_uid: str, chat_id: str) -> dict:
    db = get_firestore_client()
    docs = db.collection(_FEEDBACK).where("from_user_id", "==", from_uid).get()
    for doc in docs:
        if doc.to_dict().get("chat_id") == chat_id:
            return {"submitted": True}
    return {"submitted": False}


def _serialize(data: dict) -> dict:
    result = {}
    for k, v in data.items():
        if hasattr(v, "isoformat"):
            result[k] = v.isoformat()
        else:
            result[k] = v
    return result
