from datetime import datetime, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client, get_messaging_client
from services.route_service import get_route
from utils.geo import is_valid_sri_lanka_coords

_COLLECTION = "route_incidents"

INCIDENT_TYPES = {
    "traffic_jam",
    "accident",
    "road_closure",
    "bus_breakdown",
    "heavy_rain",
    "other",
}

_TYPE_LABELS = {
    "traffic_jam": "Traffic Jam",
    "accident": "Accident",
    "road_closure": "Road Closure",
    "bus_breakdown": "Bus Breakdown",
    "heavy_rain": "Heavy Rain",
    "other": "Incident",
}


def _notify_route(route_id: str, title: str, body: str, exclude_uid: str, data: dict) -> None:
    """Send an FCM topic notification to all subscribers of a route topic.

    Sent as a data-only message (no "notification" block) so the OS never
    auto-displays it — the app decides whether to show it, which is the only
    way to reliably honour exclude_uid in every app state, not just foreground.
    """
    messaging = get_messaging_client()
    topic = f"flts_route_{route_id}"
    try:
        messaging.send(
            messaging.Message(
                topic=topic,
                data={**data, "exclude_uid": exclude_uid, "title": title, "body": body},
            )
        )
    except Exception:
        # Non-critical — the incident is still recorded even if the push fails
        pass


def report_incident(
    uid: str,
    route_id: str,
    incident_type: str,
    description: str,
    lat: float,
    lng: float,
) -> dict:
    get_route(route_id)

    if incident_type not in INCIDENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid incident type. Must be one of: {sorted(INCIDENT_TYPES)}",
        )

    if not is_valid_sri_lanka_coords(lat, lng):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incident coordinates are outside Sri Lanka.",
        )

    now = datetime.now(timezone.utc).isoformat()
    db = get_firestore_client()

    doc_ref = db.collection(_COLLECTION).document()
    incident_data = {
        "incident_id":    doc_ref.id,
        "route_id":       route_id,
        "reported_by_uid": uid,
        "incident_type":  incident_type,
        "description":    description.strip(),
        "lat":            lat,
        "lng":            lng,
        "active":         True,
        "created_at":     now,
    }
    doc_ref.set(incident_data)

    label = _TYPE_LABELS.get(incident_type, "Incident")
    _notify_route(
        route_id=route_id,
        title=f"{label} reported on your route",
        body=incident_data["description"] or "Check the map for details.",
        exclude_uid=uid,
        data={
            "type": "incident",
            "incident_id": doc_ref.id,
            "route_id": route_id,
            "incident_type": incident_type,
        },
    )

    return incident_data


def get_route_incidents(route_id: str) -> list[dict]:
    get_route(route_id)

    db = get_firestore_client()
    docs = (
        db.collection(_COLLECTION)
        .where("route_id", "==", route_id)
        .where("active", "==", True)
        .stream()
    )
    return [doc.to_dict() for doc in docs]


def resolve_incident(incident_id: str, uid: str) -> dict:
    db = get_firestore_client()
    doc_ref = db.collection(_COLLECTION).document(incident_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Incident not found.")

    data = doc.to_dict() or {}
    if data.get("reported_by_uid") != uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only resolve incidents you reported.",
        )

    doc_ref.update({"active": False, "resolved_at": datetime.now(timezone.utc).isoformat()})
    return {"message": "Incident resolved.", "incident_id": incident_id}
