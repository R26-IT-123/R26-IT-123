from __future__ import annotations

import logging
from datetime import datetime, timezone

from firebase_admin import messaging

from services.firebase import get_firestore_client, get_messaging_client

logger = logging.getLogger(__name__)

_FCM_TOKENS_COLLECTION = "user_fcm_tokens"
_NOTIFICATIONS_COLLECTION = "route_notifications"


def save_token(user_id: str, token: str) -> None:
    db = get_firestore_client()
    db.collection(_FCM_TOKENS_COLLECTION).document(user_id).set(
        {"token": token, "updated_at": datetime.now(timezone.utc)}
    )


def _get_user_token(user_id: str) -> str | None:
    db = get_firestore_client()
    doc = db.collection(_FCM_TOKENS_COLLECTION).document(user_id).get()
    if doc.exists:
        return (doc.to_dict() or {}).get("token")
    return None


def _get_user_tokens(user_ids: list[str]) -> dict[str, str]:
    """uid -> token, for every user that has one registered."""
    tokens: dict[str, str] = {}
    for uid in user_ids:
        token = _get_user_token(uid)
        if token:
            tokens[uid] = token
    return tokens


def _clear_stale_token(user_id: str) -> None:
    """Drop a token FCM has rejected as unregistered/invalid, so it stops
    being retried on every send until the device re-registers a fresh one
    (via onTokenRefresh on next app open).
    """
    try:
        db = get_firestore_client()
        db.collection(_FCM_TOKENS_COLLECTION).document(user_id).delete()
    except Exception:
        pass


def send_to_user(
    user_id: str,
    title: str,
    body: str,
    data: dict | None = None,
    actor_id: str | None = None,
) -> None:
    data = data or {}
    create_notification(
        recipient_id=user_id,
        actor_id=actor_id,
        notif_type=data.get("type", "general"),
        title=title,
        body=body,
        data=data,
    )

    token = _get_user_token(user_id)
    if not token:
        logger.info("No FCM token registered for user %s — push skipped.", user_id)
        return
    _send(user_id, token, title, body, data, actor_id)


def broadcast_to_users(
    user_ids: list[str],
    title: str,
    body: str,
    data: dict | None = None,
    actor_id: str | None = None,
) -> None:
    data = data or {}
    notif_type = data.get("type", "general")
    for uid in user_ids:
        create_notification(
            recipient_id=uid,
            actor_id=actor_id,
            notif_type=notif_type,
            title=title,
            body=body,
            data=data,
        )

    tokens_by_uid = _get_user_tokens(user_ids)
    if not tokens_by_uid:
        return
    _send_multicast(tokens_by_uid, title, body, data, actor_id)


def _build_payload(title: str, body: str, data: dict | None, actor_id: str | None) -> dict[str, str]:
    """Data-only payload — the OS never auto-displays it, the app's
    PushNotificationService decides whether to show it, which is what lets
    it also skip the device of whoever triggered the action (exclude_uid).
    """
    payload = {k: str(v) for k, v in (data or {}).items()}
    payload["title"] = title
    payload["body"] = body
    if actor_id:
        payload["exclude_uid"] = actor_id
    return payload


def _send(user_id: str, token: str, title: str, body: str, data: dict | None, actor_id: str | None) -> None:
    msg = messaging.Message(
        data=_build_payload(title, body, data, actor_id),
        token=token,
    )
    try:
        get_messaging_client()
        messaging.send(msg)
    except messaging.UnregisteredError:
        logger.info("FCM token for user %s is stale — clearing it.", user_id)
        _clear_stale_token(user_id)
    except Exception as exc:
        logger.warning("FCM send failed for user %s: %s", user_id, exc)


def _send_multicast(
    tokens_by_uid: dict[str, str],
    title: str,
    body: str,
    data: dict | None,
    actor_id: str | None,
) -> None:
    uids = list(tokens_by_uid.keys())
    tokens = [tokens_by_uid[uid] for uid in uids]
    msg = messaging.MulticastMessage(
        data=_build_payload(title, body, data, actor_id),
        tokens=tokens,
    )
    try:
        get_messaging_client()
        response = messaging.send_each_for_multicast(msg)
        for uid, result in zip(uids, response.responses):
            if not result.success and isinstance(result.exception, messaging.UnregisteredError):
                logger.info("FCM token for user %s is stale — clearing it.", uid)
                _clear_stale_token(uid)
    except Exception as exc:
        logger.warning("FCM multicast failed: %s", exc)


def create_notification(
    recipient_id: str,
    actor_id: str | None,
    notif_type: str,
    title: str,
    body: str,
    data: dict,
) -> None:
    """Persist a bell-tray notification. Best-effort — never blocks the caller."""
    try:
        db = get_firestore_client()
        now = datetime.now(timezone.utc)
        ref = db.collection(_NOTIFICATIONS_COLLECTION).document()
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
    docs = db.collection(_NOTIFICATIONS_COLLECTION).where("recipient_id", "==", uid).get()
    results = []
    for doc in docs:
        data = doc.to_dict()
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
