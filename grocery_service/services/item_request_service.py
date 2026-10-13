from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client, get_messaging_client
from services.notification_service import COMMUNITY_RECIPIENT, create_notification

_ITEM_REQUESTS = "grocery_item_requests"
_CHATS = "grocery_chats"
_ACTIVE_HOURS = 24


def create_item_request(
    uid: str,
    display_name: str,
    supermarket: str,
    items: list[dict],
    note: str,
) -> dict:
    db = get_firestore_client()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(hours=_ACTIVE_HOURS)

    ref = db.collection(_ITEM_REQUESTS).document()
    data = {
        "id":             ref.id,
        "requester_id":   uid,
        "requester_name": display_name,
        "supermarket":    supermarket.strip(),
        "items":          items,
        "note":           note.strip(),
        "status":         "open",
        "created_at":     now,
        "expires_at":     expires_at,
    }
    ref.set(data)

    _notify_new_item_request(
        request_id=ref.id,
        requester_id=uid,
        requester_name=display_name,
        supermarket=data["supermarket"],
        note=data["note"],
    )

    return _serialize(data)


def list_item_requests() -> list[dict]:
    db = get_firestore_client()
    now = datetime.now(timezone.utc)
    docs = db.collection(_ITEM_REQUESTS).where("status", "==", "open").get()
    results = []
    for doc in docs:
        data = doc.to_dict()
        expires_at = data.get("expires_at")
        if expires_at and expires_at > now:
            results.append(_serialize(data))
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results


def list_my_item_requests(uid: str) -> list[dict]:
    db = get_firestore_client()
    docs = db.collection(_ITEM_REQUESTS).where("requester_id", "==", uid).get()
    results = [_serialize(doc.to_dict()) for doc in docs]
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results


def close_item_request(request_id: str, uid: str) -> dict:
    db = get_firestore_client()
    ref = db.collection(_ITEM_REQUESTS).document(request_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item request not found.")
    data = doc.to_dict()
    if data.get("requester_id") != uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the requester can close this request.")
    ref.update({"status": "closed"})
    return {"message": "Item request closed.", "id": request_id}


def contact_requester(request_id: str, shopper_id: str, shopper_name: str) -> dict:
    db = get_firestore_client()
    now = datetime.now(timezone.utc)

    req_doc = db.collection(_ITEM_REQUESTS).document(request_id).get()
    if not req_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item request not found.")

    req = req_doc.to_dict()
    if req.get("status") != "open":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This item request is no longer open.")

    requester_id = req["requester_id"]
    if requester_id == shopper_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot contact yourself.")

    # Return existing chat if shopper already contacted this requester
    existing = (
        db.collection(_CHATS)
        .where("item_request_id", "==", request_id)
        .where("shopper_id", "==", shopper_id)
        .limit(1)
        .get()
    )
    if existing:
        return {"message": "Chat already exists.", "chat_id": existing[0].to_dict()["id"]}

    chat_ref = db.collection(_CHATS).document()
    chat_data = {
        "id":              chat_ref.id,
        "item_request_id": request_id,
        "announcement_id": "",
        "shopper_id":      shopper_id,
        "shopper_name":    shopper_name,
        "requester_id":    requester_id,
        "requester_name":  req["requester_name"],
        "supermarket":     req["supermarket"],
        "status":          "open",
        "last_message":    None,
        "last_message_at": None,
        "created_at":      now,
    }
    chat_ref.set(chat_data)

    # Auto-post the requester's item list as the first message
    items = req.get("items") or []
    if items:
        msg_ref = (
            db.collection(_CHATS)
            .document(chat_ref.id)
            .collection("messages")
            .document()
        )
        msg_ref.set({
            "id":          msg_ref.id,
            "sender_id":   requester_id,
            "sender_name": req["requester_name"],
            "type":        "item_list",
            "content":     "",
            "sent_at":     now,
            "items":       items,
        })
        chat_ref.update({
            "last_message":    "[item list]",
            "last_message_at": now,
        })

    # Lock the request so no other shopper can accept it
    db.collection(_ITEM_REQUESTS).document(request_id).update({
        "status":  "accepted",
        "chat_id": chat_ref.id,
    })

    _notify_requester(
        requester_id=requester_id,
        shopper_id=shopper_id,
        shopper_name=shopper_name,
        supermarket=req["supermarket"],
        request_id=request_id,
        chat_id=chat_ref.id,
    )

    return {"message": "Chat opened.", "chat_id": chat_ref.id}


def _notify_new_item_request(
    request_id: str,
    requester_id: str,
    requester_name: str,
    supermarket: str,
    note: str,
) -> None:
    title = f"{requester_name} needs items from {supermarket}"
    body = note or "Tap to see what they need and offer to help."

    create_notification(
        recipient_id=COMMUNITY_RECIPIENT,
        actor_id=requester_id,
        notif_type="item_request_posted",
        title=title,
        body=body,
        data={"request_id": request_id},
    )

    messaging = get_messaging_client()
    try:
        messaging.send(
            messaging.Message(
                topic="grocery_community",
                data={
                    "type": "item_request_posted",
                    "title": title,
                    "body": body,
                    "exclude_uid": requester_id,
                    "request_id": request_id,
                },
            )
        )
    except Exception:
        pass


def _notify_requester(
    requester_id: str,
    shopper_id: str,
    shopper_name: str,
    supermarket: str,
    request_id: str,
    chat_id: str,
) -> None:
    title = f"{shopper_name} can help with your items"
    body = f"They're heading to {supermarket}. Tap to chat."

    create_notification(
        recipient_id=requester_id,
        actor_id=shopper_id,
        notif_type="item_request_accepted",
        title=title,
        body=body,
        data={"request_id": request_id, "chat_id": chat_id},
    )

    messaging = get_messaging_client()
    try:
        messaging.send(
            messaging.Message(
                topic=f"grocery_requester_{requester_id}",
                data={
                    "type": "item_request_accepted",
                    "title": title,
                    "body": body,
                    "exclude_uid": shopper_id,
                    "request_id": request_id,
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
        elif isinstance(v, list):
            result[k] = v
        else:
            result[k] = v
    return result
