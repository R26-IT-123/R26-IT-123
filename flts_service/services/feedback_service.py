from datetime import datetime, timezone
from typing import Any

from services.firebase import get_firestore_client

_BUS_FEEDBACK = "bus_feedback"


def get_feedback(vehicle_number: str) -> list[dict[str, Any]]:
    db = get_firestore_client()
    docs = (
        db.collection(_BUS_FEEDBACK)
        .where("vehicleNumber", "==", vehicle_number)
        .stream()
    )

    results = []
    for doc in docs:
        data = doc.to_dict()
        ts = data.get("timestamp")
        ts_str = ts.isoformat() if isinstance(ts, datetime) else None
        results.append({
            "feedback_id":  doc.id,
            "vehicle_number": data.get("vehicleNumber", ""),
            "route_id":     data.get("routeId", ""),
            "display_name": data.get("displayName", "Student"),
            "rating":       data.get("rating", 0),
            "type":         data.get("type", ""),
            "comment":      data.get("comment", ""),
            "timestamp":    ts_str,
        })

    # Sort newest first in Python — avoids requiring a Firestore composite index
    results.sort(key=lambda x: x["timestamp"] or "", reverse=True)
    return results


def submit_feedback(
    uid: str,
    display_name: str,
    vehicle_number: str,
    route_id: str,
    rating: int,
    feedback_type: str,
    comment: str,
) -> dict:
    now = datetime.now(timezone.utc)
    db = get_firestore_client()

    doc_ref = db.collection(_BUS_FEEDBACK).document()
    doc_ref.set({
        "vehicleNumber": vehicle_number,
        "routeId":       route_id,
        "userId":        uid,
        "displayName":   display_name,
        "rating":        rating,
        "type":          feedback_type,
        "comment":       comment,
        "timestamp":     now,
    })

    return {"message": "Feedback submitted.", "feedback_id": doc_ref.id}
