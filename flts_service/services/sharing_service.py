import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client, get_messaging_client
from services.route_service import get_route
from utils.geo import is_valid_sri_lanka_coords

logger = logging.getLogger(__name__)

_LIVE_GPS = "live_gps"
_ROUTE_ACTIVITY = "route_activity"


def start_sharing(uid: str, display_name: str, route_id: str, lat: float, lng: float, vehicle_number: str = "") -> dict:
    get_route(route_id)  # validate route exists

    if not is_valid_sri_lanka_coords(lat, lng):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="GPS coordinates are outside Sri Lanka. Cannot start sharing.",
        )

    now = datetime.now(timezone.utc)
    db = get_firestore_client()

    # Write initial GPS position
    db.collection(_LIVE_GPS).document(uid).set({
        "userId":        uid,
        "displayName":   display_name,
        "routeId":       route_id,
        "vehicleNumber": vehicle_number,
        "lat":           lat,
        "lng":           lng,
        "timestamp":     now,
    })

    # Record join event for home screen live card.
    # now is a datetime object — Firestore stores it as a Timestamp so Flutter
    # can read it as Timestamp and fire the in-app join notification.
    # merge=True + only including currentVehicleNumber when non-empty means a
    # rider who skips entering a number never wipes out one someone else on
    # the same bus already recorded.
    activity_update = {
        "routeId":               route_id,
        "lastJoinedUserId":      uid,
        "lastJoinedDisplayName": display_name,
        "lastJoinedAt":          now,
    }
    if vehicle_number:
        activity_update["currentVehicleNumber"] = vehicle_number
        activity_update["vehicleNumberUpdatedAt"] = now
    db.collection(_ROUTE_ACTIVITY).document(route_id).set(activity_update, merge=True)

    # Notify other passengers on the same route via FCM topic
    _notify_route(
        route_id=route_id,
        title="Someone joined your route",
        body=f"{display_name} is now sharing on this route.",
        exclude_uid=uid,
    )

    return {"message": "Sharing started.", "route_id": route_id}


def update_gps_tick(uid: str, display_name: str, route_id: str, lat: float, lng: float, vehicle_number: str = "") -> dict:
    """Update the live_gps position for an already-sharing user."""
    get_route(route_id)  # validate route exists

    if not is_valid_sri_lanka_coords(lat, lng):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="GPS coordinates are outside Sri Lanka.",
        )

    now = datetime.now(timezone.utc)
    db = get_firestore_client()

    db.collection(_LIVE_GPS).document(uid).set({
        "userId":        uid,
        "displayName":   display_name,
        "routeId":       route_id,
        "vehicleNumber": vehicle_number,
        "lat":           lat,
        "lng":           lng,
        "timestamp":     now,
    })

    # Keep the persisted route-level vehicle number fresh so it doesn't look
    # stale/expired while this rider is still actively on the bus.
    if vehicle_number:
        db.collection(_ROUTE_ACTIVITY).document(route_id).set(
            {"currentVehicleNumber": vehicle_number, "vehicleNumberUpdatedAt": now},
            merge=True,
        )

    return {"message": "GPS updated.", "route_id": route_id}


def stop_sharing(uid: str, display_name: str, route_id: str) -> dict:
    db = get_firestore_client()
    doc = db.collection(_LIVE_GPS).document(uid).get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are not currently sharing on any route.",
        )

    db.collection(_LIVE_GPS).document(uid).delete()

    _notify_route(
        route_id=route_id,
        title="Someone left the route",
        body=f"{display_name} stopped sharing.",
        exclude_uid=uid,
    )

    return {"message": "Sharing stopped."}


def _notify_route(route_id: str, title: str, body: str, exclude_uid: str) -> None:
    """Send an FCM topic notification to all subscribers of a route topic.

    Sent as a data-only message (no "notification" block) so the OS never
    auto-displays it — the app decides whether to show it, which is the only
    way to reliably honour exclude_uid (skip the device of whoever triggered
    the action) in every app state, not just foreground.
    """
    messaging = get_messaging_client()
    topic = f"flts_route_{route_id}"
    try:
        messaging.send(
            messaging.Message(
                topic=topic,
                data={
                    "route_id": route_id,
                    "exclude_uid": exclude_uid,
                    "title": title,
                    "body": body,
                },
            )
        )
    except Exception as exc:
        # Non-critical — sharing still works even if notification fails
        logger.warning("FCM send failed for topic %s: %s", topic, exc)
