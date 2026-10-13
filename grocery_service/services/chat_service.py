from datetime import datetime, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client, get_messaging_client
from services.notification_service import create_notification

_CHATS = "grocery_chats"
_MESSAGES = "messages"

_VALID_MESSAGE_TYPES = {
    "text", "item_list", "bill", "image",
    "payment_intent", "payment_slip",
    "payment_confirmed", "delivery_confirmed", "receipt_confirmed",
}

_PAYMENT_STATUS_MAP = {
    "payment_slip":        "slip_uploaded",
    "payment_confirmed":   "payment_confirmed",
    "delivery_confirmed":  "delivered",
    "receipt_confirmed":   "completed",
}

_LAST_MSG_LABELS = {
    "item_list":          "[item list]",
    "bill":               "[bill]",
    "image":              "[image]",
    "payment_intent":     "[cash payment confirmed]",
    "payment_slip":       "[payment slip uploaded]",
    "payment_confirmed":  "[payment confirmed]",
    "delivery_confirmed": "[items delivered]",
    "receipt_confirmed":  "[receipt confirmed]",
}


def get_my_chats(uid: str) -> list[dict]:
    db = get_firestore_client()

    as_shopper   = db.collection(_CHATS).where("shopper_id",    "==", uid).get()
    as_requester = db.collection(_CHATS).where("requester_id",  "==", uid).get()

    seen = set()
    results = []
    for doc in list(as_shopper) + list(as_requester):
        if doc.id in seen:
            continue
        seen.add(doc.id)
        data = doc.to_dict()
        if data.get("status") == "open":
            results.append(_serialize(data))

    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results


def get_messages(chat_id: str, uid: str) -> list[dict]:
    db = get_firestore_client()
    _assert_chat_member(db, chat_id, uid)

    docs = (
        db.collection(_CHATS)
        .document(chat_id)
        .collection(_MESSAGES)
        .order_by("sent_at")
        .get()
    )
    return [_serialize(doc.to_dict()) for doc in docs]


def send_message(
    chat_id: str,
    uid: str,
    display_name: str,
    msg_type: str,
    content: str,
    items: list[dict] | None,
    bill_amount: float | None,
    bill_note: str | None,
    bill_image_url: str | None = None,
    item_image_url: str | None = None,
    image_url: str | None = None,
    payment_method: str | None = None,
    slip_image_url: str | None = None,
) -> dict:
    if msg_type not in _VALID_MESSAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Message type must be one of: {', '.join(sorted(_VALID_MESSAGE_TYPES))}",
        )

    db = get_firestore_client()
    chat_data = _assert_chat_member(db, chat_id, uid)
    now = datetime.now(timezone.utc)

    msg_ref = db.collection(_CHATS).document(chat_id).collection(_MESSAGES).document()
    msg_data: dict = {
        "id":          msg_ref.id,
        "sender_id":   uid,
        "sender_name": display_name,
        "type":        msg_type,
        "content":     content.strip(),
        "sent_at":     now,
    }

    if msg_type == "item_list":
        msg_data["items"] = items or []
        if item_image_url:
            msg_data["item_image_url"] = item_image_url

    elif msg_type == "bill":
        if bill_amount is None or bill_amount <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="bill_amount is required and must be greater than 0 for bill messages.",
            )
        msg_data["bill_amount"] = bill_amount
        msg_data["bill_note"]   = bill_note or ""
        if bill_image_url:
            msg_data["bill_image_url"] = bill_image_url

    elif msg_type == "image":
        if not image_url:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="image_url is required for image messages.",
            )
        msg_data["image_url"] = image_url

    elif msg_type == "payment_intent":
        if payment_method not in ("cash", "online"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="payment_method must be 'cash' or 'online'.",
            )
        msg_data["payment_method"] = payment_method

    elif msg_type == "payment_slip":
        if not slip_image_url:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="slip_image_url is required for payment_slip messages.",
            )
        msg_data["slip_image_url"] = slip_image_url

    msg_ref.set(msg_data)

    # Build chat document update
    last_msg_text = (
        content.strip() if msg_type == "text"
        else _LAST_MSG_LABELS.get(msg_type, f"[{msg_type}]")
    )
    chat_update: dict = {
        "last_message":    last_msg_text,
        "last_message_at": now,
    }

    if msg_type == "payment_intent":
        chat_update["payment_status"] = "cash_pending" if payment_method == "cash" else "online_pending"
    elif msg_type in _PAYMENT_STATUS_MAP:
        chat_update["payment_status"] = _PAYMENT_STATUS_MAP[msg_type]

    db.collection(_CHATS).document(chat_id).update(chat_update)

    other_id = (
        chat_data["requester_id"] if uid == chat_data["shopper_id"] else chat_data["shopper_id"]
    )
    _notify_chat_member(
        recipient_id=other_id,
        sender_id=uid,
        sender_name=display_name,
        chat_id=chat_id,
        msg_type=msg_type,
        content=content,
        bill_amount=bill_amount,
    )

    return _serialize(msg_data)


_DELETABLE_TYPES = {"text", "image"}


def delete_message(chat_id: str, message_id: str, uid: str) -> dict:
    db = get_firestore_client()
    _assert_chat_member(db, chat_id, uid)

    msg_ref = (
        db.collection(_CHATS)
        .document(chat_id)
        .collection(_MESSAGES)
        .document(message_id)
    )
    msg_doc = msg_ref.get()
    if not msg_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found.")

    msg_data = msg_doc.to_dict()
    if msg_data.get("sender_id") != uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only delete your own messages.")
    if msg_data.get("type") not in _DELETABLE_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This message type cannot be deleted.")

    msg_ref.delete()
    return {"message": "Message deleted.", "message_id": message_id}


def close_chat(chat_id: str, uid: str) -> dict:
    db = get_firestore_client()
    _assert_chat_member(db, chat_id, uid)
    db.collection(_CHATS).document(chat_id).update({"status": "closed"})
    return {"message": "Chat closed.", "chat_id": chat_id}


def _assert_chat_member(db, chat_id: str, uid: str) -> dict:
    doc = db.collection(_CHATS).document(chat_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found.")
    data = doc.to_dict()
    if uid not in (data.get("shopper_id"), data.get("requester_id")):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not a member of this chat.")
    return data


def _notify_chat_member(
    recipient_id: str,
    sender_id: str,
    sender_name: str,
    chat_id: str,
    msg_type: str,
    content: str,
    bill_amount: float | None,
) -> None:
    if msg_type == "bill":
        body = f"Bill added: LKR {bill_amount:.2f}"
    elif msg_type == "item_list":
        body = "Sent an item list"
    elif msg_type == "payment_intent":
        body = "Will pay cash on delivery"
    elif msg_type == "payment_slip":
        body = "Uploaded a payment slip"
    elif msg_type == "payment_confirmed":
        body = "Payment confirmed"
    elif msg_type == "delivery_confirmed":
        body = "Items marked as delivered"
    elif msg_type == "receipt_confirmed":
        body = "Receipt confirmed — transaction complete"
    else:
        body = content[:80] if content else "New message"

    title = f"{sender_name} (Grocery Chat)"

    create_notification(
        recipient_id=recipient_id,
        actor_id=sender_id,
        notif_type="chat_message",
        title=title,
        body=body,
        data={"chat_id": chat_id, "message_type": msg_type},
    )

    messaging = get_messaging_client()
    try:
        messaging.send(
            messaging.Message(
                topic=f"grocery_chat_{recipient_id}",
                data={
                    "type": "chat_message",
                    "title": title,
                    "body": body,
                    "exclude_uid": sender_id,
                    "chat_id": chat_id,
                    "message_type": msg_type,
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
        elif isinstance(v, list):
            result[k] = v
        else:
            result[k] = v
    return result
