from datetime import datetime, timezone

from services.firebase import get_firestore_client

_NOTIFICATIONS = "grocery_notifications"

# Sentinel recipient for broadcast notifications (e.g. community announcements)
# that aren't addressed to one specific uid.
COMMUNITY_RECIPIENT = "community"


def create_notification(
    recipient_id: str,
    actor_id: str,
    notif_type: str,
    title: str,
    body: str,
    data: dict,
) -> None:
    """Persist a bell-tray notification. Best-effort — never blocks the caller."""
    try:
        db = get_firestore_client()
        now = datetime.now(timezone.utc)
        ref = db.collection(_NOTIFICATIONS).document()
        ref.set({
            "id":           ref.id,
            "recipient_id": recipient_id,
            "actor_id":     actor_id,
            "type":         notif_type,
            "title":        title,
            "body":         body,
            "data":         data,
            "created_at":   now,
        })
    except Exception:
        pass


def list_notifications(uid: str, limit: int = 50) -> list[dict]:
    db = get_firestore_client()
    docs = (
        db.collection(_NOTIFICATIONS)
        .where("recipient_id", "in", [uid, COMMUNITY_RECIPIENT])
        .get()
    )
    results = []
    for doc in docs:
        data = doc.to_dict()
        # Don't show a user their own broadcast/action back to themselves.
        if data.get("actor_id") == uid:
            continue
        results.append(_serialize(data))
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results[:limit]


def _serialize(data: dict) -> dict:
    result = {}
    for k, v in data.items():
        if hasattr(v, "isoformat"):
            result[k] = v.isoformat()
        else:
            result[k] = v
    return result
