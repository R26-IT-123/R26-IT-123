from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from google.cloud.firestore_v1 import FieldFilter

from schemas.booking import BookingCreate
from services.firebase import get_firestore_client
from utils.fare import (
    UPFRONT_PAYMENT_MIN_DAYS,
    adjusted_price_for_pickup,
    calculate_fare,
    pickme_estimate,
)
from utils.geo import decode_polyline, remaining_distance_km, snap_to_polyline

_BOOKINGS_COL = "routesharing_bookings"
_ROUTES_COL = "routesharing_routes"
_FARE_COL = "routesharing_fare_calculations"
_PRIORITY_COL = "routesharing_priority_seats"
_USERS_COL = "users"

_HOLD_MINUTES = 30
_PAYMENT_HOLD_DAYS = 2
_ABSENCES_COL = "routesharing_absences"
_WEEKDAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


def _get_route_or_404(db, route_id: str) -> dict:
    doc = db.collection(_ROUTES_COL).document(route_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")
    data = doc.to_dict() or {}
    data["id"] = doc.id
    return data


def _get_booking_or_404(db, booking_id: str) -> tuple:
    doc_ref = db.collection(_BOOKINGS_COL).document(booking_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found.")
    return doc_ref, doc.to_dict() or {}


def compute_fare_breakdown(route: dict, booking_data: BookingCreate) -> dict:
    distance_km = route.get("total_distance_km") or 0.0
    price_per_trip = route.get("price_per_trip", 0.0)
    if route.get("has_return_trip") and booking_data.wants_return_trip:
        price_per_trip *= 2
    days_count = len(booking_data.days_selected)

    # Intermediate boarding adjustment
    adjusted_price = None
    pickup_dist_km = None
    if booking_data.pickup_lat is not None and booking_data.pickup_lng is not None and distance_km > 0:
        polyline_str = route.get("route_polyline") or ""
        if polyline_str:
            coords = decode_polyline(polyline_str)
            snap_lat, snap_lng, seg_idx = snap_to_polyline(
                booking_data.pickup_lat, booking_data.pickup_lng, coords
            )
            pickup_dist_km = remaining_distance_km(coords, snap_lat, snap_lng, seg_idx)
            adjusted_price = adjusted_price_for_pickup(price_per_trip, distance_km, pickup_dist_km)

    fare_data = calculate_fare(price_per_trip, days_count, adjusted_price)
    price_per_km = round(price_per_trip / distance_km, 2) if distance_km > 0 else None
    pickme_eq = pickme_estimate(pickup_dist_km if pickup_dist_km else distance_km) if distance_km > 0 else None

    result = {
        "route_distance_km": distance_km,
        "pickup_distance_km": pickup_dist_km,
        "price_per_trip": price_per_trip,
        "price_per_km": price_per_km,
        "days_count": days_count,
        "booking_type": booking_data.booking_type,
        "discount_pct": fare_data["discount_pct"],
        "discount_amount": fare_data["discount_amount"],
        "total_fare": fare_data["total_fare"],
        "payment_type": fare_data["payment_type"],
        "pickme_equivalent": pickme_eq,
        "saving_vs_pickme": round(pickme_eq - fare_data["total_fare"], 2) if pickme_eq else None,
    }

    if booking_data.add_friend_seat:
        result["friend_seat_subtotal"] = fare_data["total_fare"]
        result["combined_total"] = round(fare_data["total_fare"] * 2, 2)

    return result


def create_booking(passenger_id: str, data: BookingCreate) -> dict:
    # The payment pipeline (upfront + driver approval vs. pay-after-ride) is
    # derived from the number of days actually selected, not trusted from
    # the client, so a request can't claim "daily" pricing for a multi-day
    # commitment or vice versa.
    data.booking_type = "weekly" if len(data.days_selected) >= UPFRONT_PAYMENT_MIN_DAYS else "daily"

    db = get_firestore_client()
    route = _get_route_or_404(db, data.route_id)
    passenger_profile = db.collection(_USERS_COL).document(passenger_id).get()
    if not passenger_profile.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    passenger_profile_data = passenger_profile.to_dict() or {}
    passenger_preferred_route_id = passenger_profile_data.get("preferred_route_id")
    passenger_year = passenger_profile_data.get("year")

    if not passenger_preferred_route_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Set your preferred route before booking a shared ride.",
        )

    driver_profile = db.collection(_USERS_COL).document(route["driver_id"]).get()
    driver_preferred_route_id = (driver_profile.to_dict() or {}).get("preferred_route_id") if driver_profile.exists else None

    if not driver_preferred_route_id or passenger_preferred_route_id != driver_preferred_route_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only book rides shared for your preferred route.",
        )

    if route.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Route is not active.")

    # Validate days — only if the route uses the legacy travel_days field
    route_days = set(route.get("travel_days") or [])
    if route_days:
        for day in data.days_selected:
            if day not in route_days:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Day '{day}' is not a travel day for this route.",
                )

    if route.get("seats_available", 0) < (2 if data.add_friend_seat else 1):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Not enough seats available.")

    fare_breakdown = compute_fare_breakdown(route, data)

    # Calculate friend's fare with their own pickup if provided
    friend_fare_amount = None
    if data.add_friend_seat:
        if data.friend_pickup_lat is not None and data.friend_pickup_lng is not None:
            friend_booking_data = BookingCreate(
                route_id=data.route_id,
                booking_type=data.booking_type,
                days_selected=data.days_selected,
                pickup_lat=data.friend_pickup_lat,
                pickup_lng=data.friend_pickup_lng,
                pickup_address=data.friend_pickup_address,
                wants_return_trip=data.wants_return_trip,
            )
            friend_breakdown = compute_fare_breakdown(route, friend_booking_data)
            friend_fare_amount = friend_breakdown["total_fare"]
        else:
            friend_fare_amount = fare_breakdown["total_fare"]

    now = datetime.now(timezone.utc)
    hold_expires = now + timedelta(minutes=_HOLD_MINUTES)

    booking_doc = {
        "passenger_id": passenger_id,
        "route_id": data.route_id,
        "driver_id": route["driver_id"],
        "booking_type": data.booking_type,
        "days_selected": list(data.days_selected),
        "fare_amount": fare_breakdown["total_fare"],
        "adjusted_fare": fare_breakdown.get("total_fare"),
        "pickup_distance_km": fare_breakdown.get("pickup_distance_km"),
        "pickup_location": {
            "lat": data.pickup_lat,
            "lng": data.pickup_lng,
            "address": data.pickup_address,
        } if data.pickup_lat is not None else None,
        "add_friend_seat": data.add_friend_seat,
        "friend_name": data.friend_name,
        "friend_contact": data.friend_contact,
        "friend_pickup_location": {
            "lat": data.friend_pickup_lat,
            "lng": data.friend_pickup_lng,
            "address": data.friend_pickup_address,
        } if data.friend_pickup_lat is not None else None,
        "friend_fare_amount": friend_fare_amount,
        "wants_return_trip": bool(route.get("has_return_trip")) and data.wants_return_trip,
        "passenger_year": passenger_year,
        "status": "pending_approval",
        "priority": False,
        "seat_number": None,
        "hold_expires_at": hold_expires,
        "created_at": now,
    }

    _, ref = db.collection(_BOOKINGS_COL).add(booking_doc)
    booking_doc["id"] = ref.id

    # Store fare calculation record
    db.collection(_FARE_COL).document(ref.id).set({
        "booking_id": ref.id,
        **{k: v for k, v in fare_breakdown.items()},
        "created_at": now,
    })

    return booking_doc


def get_booking(booking_id: str) -> dict:
    db = get_firestore_client()
    _, data = _get_booking_or_404(db, booking_id)
    data["id"] = booking_id
    return data


def list_bookings_for_passenger(passenger_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = db.collection(_BOOKINGS_COL).where(
        filter=FieldFilter("passenger_id", "==", passenger_id)
    ).stream()
    results = []
    for doc in docs:
        d = doc.to_dict() or {}
        d["id"] = doc.id
        results.append(d)
    return results


def list_bookings_for_driver(driver_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = db.collection(_BOOKINGS_COL).where(
        filter=FieldFilter("driver_id", "==", driver_id)
    ).stream()
    results = []
    for doc in docs:
        d = doc.to_dict() or {}
        d["id"] = doc.id
        passenger_id = d.get("passenger_id")
        if passenger_id:
            try:
                p = db.collection(_USERS_COL).document(passenger_id).get()
                if p.exists:
                    d["passenger_year"] = (p.to_dict() or {}).get("year")
            except Exception:
                pass
        results.append(d)
    return results


def approve_booking(booking_id: str, driver_id: str, note: str | None = None) -> dict:
    db = get_firestore_client()
    doc_ref, booking = _get_booking_or_404(db, booking_id)

    if booking.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    current_status = booking.get("status")
    allowed = {"pending_approval", "payment_uploaded"}
    if current_status not in allowed:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot approve booking in status '{current_status}'.",
        )

    # Check hold has not expired
    hold_exp = booking.get("hold_expires_at")
    if hold_exp and datetime.now(timezone.utc) > hold_exp:
        doc_ref.update({"status": "expired"})
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="Booking hold has expired.")

    # 1st approval for weekly booking: accept booking, give passenger 2 days to upload slip
    if current_status == "pending_approval" and booking.get("booking_type") == "weekly":
        new_hold = datetime.now(timezone.utc) + timedelta(days=_PAYMENT_HOLD_DAYS)
        doc_ref.update({
            "status": "booking_approved",
            "hold_expires_at": new_hold,
            "approved_note": note,
        })
        booking["status"] = "booking_approved"
        booking["hold_expires_at"] = new_hold
        booking["approved_note"] = note
        booking["id"] = booking_id
        return booking

    # Daily booking (1st approval) or weekly 2nd approval after slip upload → confirmed
    updates: dict = {"status": "confirmed", "approved_note": note}

    # Decrement seats on route
    route_ref = db.collection(_ROUTES_COL).document(booking["route_id"])
    seat_delta = 2 if booking.get("add_friend_seat") else 1
    route_doc = route_ref.get()
    if route_doc.exists:
        available = (route_doc.to_dict() or {}).get("seats_available", 0)
        route_ref.update({"seats_available": max(0, available - seat_delta)})

    # Assign priority seat for weekly full-week bookings
    if booking.get("booking_type") == "weekly" and len(booking.get("days_selected", [])) == 5:
        updates["priority"] = True
        existing_seats = db.collection(_PRIORITY_COL).where(
            filter=FieldFilter("route_id", "==", booking["route_id"])
        ).stream()
        used_seats = {(s.to_dict() or {}).get("seat_number", 0) for s in existing_seats}
        seat_num = next(i for i in range(1, 20) if i not in used_seats)
        updates["seat_number"] = seat_num

        db.collection(_PRIORITY_COL).add({
            "booking_id": booking_id,
            "route_id": booking["route_id"],
            "passenger_id": booking["passenger_id"],
            "seat_number": seat_num,
            "week_start_date": booking.get("days_selected", [None])[0],
            "status": "active",
        })

    doc_ref.update(updates)
    booking.update(updates)
    booking["id"] = booking_id
    return booking


def decline_booking(booking_id: str, driver_id: str, reason: str | None = None) -> dict:
    db = get_firestore_client()
    doc_ref, booking = _get_booking_or_404(db, booking_id)

    if booking.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    doc_ref.update({"status": "declined", "decline_reason": reason})
    booking["status"] = "declined"
    booking["id"] = booking_id
    return booking


def request_payment(booking_id: str, driver_id: str) -> dict:
    db = get_firestore_client()
    doc_ref, booking = _get_booking_or_404(db, booking_id)

    if booking.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    if booking.get("status") != "pending_approval":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Booking is not in pending_approval status.",
        )

    new_hold = datetime.now(timezone.utc) + timedelta(minutes=_HOLD_MINUTES + _PAYMENT_HOLD_EXTENSION_MINUTES)
    doc_ref.update({"status": "pending_payment", "hold_expires_at": new_hold})
    booking["status"] = "pending_payment"
    booking["id"] = booking_id
    return booking


def notify_absence(booking_id: str, passenger_id: str, ride_date: str, reason: str | None) -> dict:
    db = get_firestore_client()
    doc_ref, booking = _get_booking_or_404(db, booking_id)

    if booking.get("passenger_id") != passenger_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    if booking.get("status") != "confirmed":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Booking is not confirmed.")

    try:
        parsed_date = datetime.strptime(ride_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ride_date must be in YYYY-MM-DD format.",
        )

    if parsed_date < datetime.now(timezone.utc).date():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot report absence for a past date.",
        )

    weekday_key = _WEEKDAY_KEYS[parsed_date.weekday()]
    if weekday_key not in (booking.get("days_selected") or []):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ride_date is not one of this booking's scheduled days.",
        )

    absence_col = db.collection(_ABSENCES_COL)
    existing = (
        absence_col
        .where(filter=FieldFilter("booking_id", "==", booking_id))
        .where(filter=FieldFilter("ride_date", "==", ride_date))
        .limit(1)
        .get()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Absence already reported for this date.",
        )

    absence_doc = {
        "booking_id": booking_id,
        "route_id": booking["route_id"],
        "driver_id": booking["driver_id"],
        "passenger_id": passenger_id,
        "ride_date": ride_date,
        "reason": reason,
        "notified_at": datetime.now(timezone.utc),
        "status": "notified",
    }
    _, ref = absence_col.add(absence_doc)
    absence_doc["id"] = ref.id

    passenger_profile = db.collection(_USERS_COL).document(passenger_id).get()
    absence_doc["passenger_name"] = (
        (passenger_profile.to_dict() or {}).get("full_name") if passenger_profile.exists else None
    )

    route_doc = db.collection(_ROUTES_COL).document(booking["route_id"]).get()
    route_data = route_doc.to_dict() or {} if route_doc.exists else {}
    absence_doc["route_start_address"] = (route_data.get("start_location") or {}).get("address")
    absence_doc["route_destination"] = route_data.get("destination")

    return absence_doc


def get_fare_breakdown(booking_id: str) -> dict:
    db = get_firestore_client()
    doc = db.collection(_FARE_COL).document(booking_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fare record not found.")
    return doc.to_dict() or {}
