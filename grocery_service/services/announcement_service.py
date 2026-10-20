from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client, get_messaging_client
from services.notification_service import COMMUNITY_RECIPIENT, create_notification

_ANNOUNCEMENTS = "grocery_announcements"
_ANNOUNCEMENT_ACTIVE_HOURS = 3


def create_announcement(uid: str, display_name: str, supermarket: str, message: str) -> dict:
    db = get_firestore_client()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(hours=_ANNOUNCEMENT_ACTIVE_HOURS)

    ref = db.collection(_ANNOUNCEMENTS).document()
    data = {
        "id":            ref.id,
        "shopper_id":    uid,
        "shopper_name":  display_name,
        "supermarket":   supermarket.strip(),
        "message":       message.strip(),
        "status":        "active",
        "created_at":    now,
        "expires_at":    expires_at,
    }
    ref.set(data)

    _notify_community(
        announcement_id=ref.id,
        actor_id=uid,
        title=f"{display_name} is going to {supermarket}",
        body=message.strip() or f"Anyone need items from {supermarket}?",
    )

    return _serialize(data)


def list_announcements() -> list[dict]:
    db = get_firestore_client()
    now = datetime.now(timezone.utc)
    # Single-field query only — avoids composite index requirement.
    # Expiry and sorting applied in Python.
    docs = db.collection(_ANNOUNCEMENTS).where("status", "==", "active").get()
    results = []
    for doc in docs:
        data = doc.to_dict()
        expires_at = data.get("expires_at")
        if expires_at and expires_at > now:
            results.append(_serialize(data))
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results


def close_announcement(announcement_id: str, uid: str) -> dict:
    db = get_firestore_client()
    ref = db.collection(_ANNOUNCEMENTS).document(announcement_id)
    doc = ref.get()

    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found.")

    data = doc.to_dict()
    if data.get("shopper_id") != uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the shopper can close this announcement.")

    ref.update({"status": "closed"})
    return {"message": "Announcement closed.", "id": announcement_id}


def get_announcement(announcement_id: str) -> dict:
    db = get_firestore_client()
    doc = db.collection(_ANNOUNCEMENTS).document(announcement_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found.")
    return _serialize(doc.to_dict())


def _notify_community(announcement_id: str, actor_id: str, title: str, body: str) -> None:
    create_notification(
        recipient_id=COMMUNITY_RECIPIENT,
        actor_id=actor_id,
        notif_type="announcement",
        title=title,
        body=body,
        data={"announcement_id": announcement_id},
    )

    messaging = get_messaging_client()
    try:
        messaging.send(
            messaging.Message(
                topic="grocery_community",
                data={
                    "type": "announcement",
                    "title": title,
                    "body": body,
                    "exclude_uid": actor_id,
                    "announcement_id": announcement_id,
                },
            )
        )
    except Exception:
        pass


def _serialize(data: dict) -> dict:
    result = {}
    for k, v in data.items():
        if hasattr(v, "isoformat"):
            result[k] = v.isoformat()
        else:
            result[k] = v
    return result
