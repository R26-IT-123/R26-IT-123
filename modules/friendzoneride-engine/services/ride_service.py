from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status
from google.cloud.firestore_v1 import FieldFilter

from services.firebase import get_firestore_client

_SESSIONS_COL = "routesharing_ride_sessions"
_ROUTES_COL = "routesharing_routes"
_BOOKINGS_COL = "routesharing_bookings"
_LIVE_LOC_COL = "routesharing_live_locations"
_USERS_COL = "users"


def _get_session_or_404(db, session_id: str) -> tuple:
    doc_ref = db.collection(_SESSIONS_COL).document(session_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride session not found.")
    return doc_ref, doc.to_dict() or {}


def start_ride(route_id: str, driver_id: str, ride_date: str) -> dict:
    db = get_firestore_client()

    # Verify route belongs to driver
    route_doc = db.collection(_ROUTES_COL).document(route_id).get()
    if not route_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")
    route = route_doc.to_dict() or {}
    if route.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your route.")

    # Prevent duplicate sessions for same route+date (active or already completed)
    existing = list(
        db.collection(_SESSIONS_COL)
        .where(filter=FieldFilter("route_id", "==", route_id))
        .where(filter=FieldFilter("ride_date", "==", ride_date))
        .limit(1)
        .stream()
    )
    if existing:
        existing_status = (existing[0].to_dict() or {}).get("status", "active")
        if existing_status == "completed":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A trip for this date has already been completed.",
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An active session already exists for this route and date.",
        )

    # Collect approved/confirmed passengers for this day of week
    ride_day = _date_to_day(ride_date)
    bookings = db.collection(_BOOKINGS_COL).where(
        filter=FieldFilter("route_id", "==", route_id)
    ).where(filter=FieldFilter("status", "in", ["confirmed", "booking_approved", "payment_uploaded"])).stream()

    passenger_ids = []
    for doc in bookings:
        b = doc.to_dict() or {}
        if ride_day in (b.get("days_selected") or []):
            passenger_ids.append(b.get("passenger_id"))

    now = datetime.now(timezone.utc)
    session_doc = {
        "route_id": route_id,
        "driver_id": driver_id,
        "ride_date": ride_date,
        "start_time": now,
        "end_time": None,
        "status": "active",
        "passenger_ids": passenger_ids,
    }
    _, ref = db.collection(_SESSIONS_COL).add(session_doc)
    session_doc["id"] = ref.id
    return session_doc


def end_ride(session_id: str, driver_id: str) -> dict:
    db = get_firestore_client()
    doc_ref, session = _get_session_or_404(db, session_id)

    if session.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your session.")

    if session.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Session is not active.")

    now = datetime.now(timezone.utc)
    doc_ref.update({"status": "completed", "end_time": now})

    # Clean up live location data
    live_docs = db.collection(_LIVE_LOC_COL).where(
        filter=FieldFilter("session_id", "==", session_id)
    ).stream()
    for d in live_docs:
        d.reference.delete()

    session["status"] = "completed"
    session["end_time"] = now
    session["id"] = session_id
    return session


def get_active_session_for_route(route_id: str) -> dict | None:
    db = get_firestore_client()
    docs = list(
        db.collection(_SESSIONS_COL)
        .where(filter=FieldFilter("route_id", "==", route_id))
        .where(filter=FieldFilter("status", "==", "active"))
        .limit(1)
        .stream()
    )
    if not docs:
        return None
    data = docs[0].to_dict() or {}
    data["id"] = docs[0].id
    return data


def get_session(session_id: str) -> dict:
    db = get_firestore_client()
    _, session = _get_session_or_404(db, session_id)
    session["id"] = session_id
    return session


def update_driver_location(session_id: str, driver_id: str, lat: float, lng: float) -> None:
    db = get_firestore_client()
    _, session = _get_session_or_404(db, session_id)

    if session.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your session.")

    if session.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Session is not active.")

    db.collection(_LIVE_LOC_COL).document(f"{session_id}_driver").set({
        "session_id": session_id,
        "user_id": driver_id,
        "role": "driver",
        "lat": lat,
        "lng": lng,
        "timestamp": datetime.now(timezone.utc),
    })


def update_passenger_location(session_id: str, passenger_id: str, lat: float, lng: float) -> None:
    db = get_firestore_client()
    _, session = _get_session_or_404(db, session_id)

    if passenger_id not in (session.get("passenger_ids") or []):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a passenger on this session.")

    if session.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Session is not active.")

    db.collection(_LIVE_LOC_COL).document(f"{session_id}_{passenger_id}").set({
        "session_id": session_id,
        "user_id": passenger_id,
        "role": "passenger",
        "lat": lat,
        "lng": lng,
        "timestamp": datetime.now(timezone.utc),
    }, merge=True)


def signal_driver_arrival(session_id: str, driver_id: str, passenger_id: str) -> None:
    db = get_firestore_client()
    _, session = _get_session_or_404(db, session_id)

    if session.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your session.")

    if session.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Session is not active.")

    if passenger_id not in (session.get("passenger_ids") or []):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Passenger not in session.")

    db.collection(_LIVE_LOC_COL).document(f"{session_id}_{passenger_id}").set(
        {"driver_arrived_at": datetime.now(timezone.utc)},
        merge=True,
    )


def confirm_passenger_boarding(session_id: str, passenger_id: str) -> None:
    db = get_firestore_client()
    _, session = _get_session_or_404(db, session_id)

    if passenger_id not in (session.get("passenger_ids") or []):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a passenger on this session.")

    if session.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Session is not active.")

    db.collection(_LIVE_LOC_COL).document(f"{session_id}_{passenger_id}").set(
        {"passenger_boarded": True},
        merge=True,
    )


def get_session_passengers(session_id: str) -> list[dict]:
    db = get_firestore_client()
    _, session = _get_session_or_404(db, session_id)

    route_id = session.get("route_id")
    ride_date = session.get("ride_date")
    ride_day = _date_to_day(ride_date) if ride_date else None

    bookings = db.collection(_BOOKINGS_COL).where(
        filter=FieldFilter("route_id", "==", route_id)
    ).where(filter=FieldFilter("status", "in", ["confirmed", "booking_approved", "payment_uploaded"])).stream()

    passengers = []
    for doc in bookings:
        b = doc.to_dict() or {}
        if ride_day and ride_day not in (b.get("days_selected") or []):
            continue

        passenger_id = b.get("passenger_id")
        user_doc = db.collection(_USERS_COL).document(passenger_id).get()
        user_data = user_doc.to_dict() if user_doc.exists else {}

        # Check if trip is paid
        from services.payment_service import _TRIP_PAYMENTS_COL
        paid_docs = list(
            db.collection(_TRIP_PAYMENTS_COL)
            .where(filter=FieldFilter("booking_id", "==", doc.id))
            .where(filter=FieldFilter("ride_session_id", "==", session_id))
            .limit(1)
            .stream()
        )

        pickup = b.get("pickup_location") or {}
        passengers.append({
            "booking_id": doc.id,
            "passenger_id": passenger_id,
            "passenger_name": user_data.get("name") or user_data.get("displayName"),
            "pickup_lat": pickup.get("lat"),
            "pickup_lng": pickup.get("lng"),
            "pickup_address": pickup.get("address"),
            "pickup_distance_from_start_km": b.get("pickup_distance_km"),
            "fare_amount": b.get("fare_amount", 0),
            "booking_type": b.get("booking_type"),
            "payment_status": "paid" if paid_docs else "pending",
        })

    return passengers


def _date_to_day(date_str: str | None) -> str | None:
    if not date_str:
        return None
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        return ["mon", "tue", "wed", "thu", "fri", "sat", "sun"][dt.weekday()]
    except ValueError:
        return None
