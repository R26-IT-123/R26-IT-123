from services.firebase import get_messaging_client

_TOPIC = "community_chat"


def notify_new_message(sender_name: str, text: str, exclude_uid: str) -> None:
    """Send an FCM topic notification to every student subscribed to the
    community chat room.

    Sent as a data-only message (no "notification" block) so the OS never
    auto-displays it — the app decides whether to show it, which is the only
    way to reliably honour exclude_uid in every app state, not just foreground.
    """
    messaging = get_messaging_client()
    body = text.strip()[:120] or "Sent a message"
    try:
        messaging.send(
            messaging.Message(
                topic=_TOPIC,
                data={
                    "type": "community_chat",
                    "title": sender_name,
                    "body": body,
                    "exclude_uid": exclude_uid,
                },
            )
        )
    except Exception:
        # Non-critical — the chat message is already stored in Firestore
        # even if the push notification fails to send.
        pass
