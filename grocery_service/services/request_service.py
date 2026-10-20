from datetime import datetime, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client, get_messaging_client
from services.notification_service import create_notification

_ANNOUNCEMENTS = "grocery_announcements"
_REQUESTS = "grocery_requests"
_CHATS = "grocery_chats"


def send_request(announcement_id: str, requester_id: str, requester_name: str) -> dict:
    db = get_firestore_client()
    now = datetime.now(timezone.utc)

    ann_doc = db.collection(_ANNOUNCEMENTS).document(announcement_id).get()
    if not ann_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found.")

    ann = ann_doc.to_dict()
    if ann.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This announcement is no longer active.")

    shopper_id = ann["shopper_id"]
    if shopper_id == requester_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot request from your own announcement.")

    # Block duplicate requests
    existing = (
        db.collection(_REQUESTS)
        .where("announcement_id", "==", announcement_id)
        .where("requester_id", "==", requester_id)
        .limit(1)
        .get()
    )
    if existing:
        existing_data = existing[0].to_dict()
        return {"message": "Request already sent.", "chat_id": existing_data["chat_id"], "request_id": existing_data["id"]}

    # Create the private chat first
    chat_ref = db.collection(_CHATS).document()
    chat_data = {
        "id":              chat_ref.id,
        "announcement_id": announcement_id,
        "shopper_id":      shopper_id,
        "shopper_name":    ann["shopper_name"],
        "requester_id":    requester_id,
        "requester_name":  requester_name,
        "supermarket":     ann["supermarket"],
        "status":          "open",
        "last_message":    None,
        "last_message_at": None,
        "created_at":      now,
    }
    chat_ref.set(chat_data)

    # Create the request record
    req_ref = db.collection(_REQUESTS).document()
    req_data = {
        "id":              req_ref.id,
        "announcement_id": announcement_id,
        "requester_id":    requester_id,
        "requester_name":  requester_name,
        "shopper_id":      shopper_id,
        "chat_id":         chat_ref.id,
        "status":          "pending",
        "created_at":      now,
    }
    req_ref.set(req_data)

    # Notify the shopper
    _notify_shopper(
        shopper_id=shopper_id,
        requester_id=requester_id,
        requester_name=requester_name,
        supermarket=ann["supermarket"],
        announcement_id=announcement_id,
        chat_id=chat_ref.id,
    )

    return {"message": "Request sent. Chat opened.", "chat_id": chat_ref.id, "request_id": req_ref.id}


def list_requests_for_announcement(announcement_id: str, uid: str) -> list[dict]:
    db = get_firestore_client()

    ann_doc = db.collection(_ANNOUNCEMENTS).document(announcement_id).get()
    if not ann_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found.")

    ann = ann_doc.to_dict()
    if ann.get("shopper_id") != uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the shopper can view requests for this announcement.")

    docs = db.collection(_REQUESTS).where("announcement_id", "==", announcement_id).get()
    results = [_serialize(doc.to_dict()) for doc in docs]
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results


def _notify_shopper(
    shopper_id: str,
    requester_id: str,
    requester_name: str,
    supermarket: str,
    announcement_id: str,
    chat_id: str,
) -> None:
    title = f"{requester_name} wants items from {supermarket}"
    body = "Tap to open the chat and see their list."

    create_notification(
        recipient_id=shopper_id,
        actor_id=requester_id,
        notif_type="item_request_received",
        title=title,
        body=body,
        data={"announcement_id": announcement_id, "chat_id": chat_id},
    )

    messaging = get_messaging_client()
    try:
        messaging.send(
            messaging.Message(
                topic=f"grocery_shopper_{shopper_id}",
                data={
                    "type": "item_request_received",
                    "title": title,
                    "body": body,
                    "exclude_uid": requester_id,
                    "announcement_id": announcement_id,
                    "chat_id": chat_id,
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
