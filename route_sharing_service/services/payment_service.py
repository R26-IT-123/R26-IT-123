from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status
from google.cloud.firestore_v1 import FieldFilter

from services.firebase import get_firestore_client

_SLIPS_COL = "routesharing_payment_slips"
_BOOKINGS_COL = "routesharing_bookings"
_TRIP_PAYMENTS_COL = "routesharing_trip_payments"


def _get_booking_or_404(db, booking_id: str) -> dict:
    doc = db.collection(_BOOKINGS_COL).document(booking_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found.")
    data = doc.to_dict() or {}
    data["id"] = doc.id
    return data


def submit_payment_slip(booking_id: str, passenger_id: str, slip_image_url: str) -> dict:
    db = get_firestore_client()
    booking = _get_booking_or_404(db, booking_id)

    if booking.get("passenger_id") != passenger_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    if booking.get("status") != "booking_approved":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Booking is not awaiting payment.",
        )

    now = datetime.now(timezone.utc)
    slip_doc = {
        "booking_id": booking_id,
        "passenger_id": passenger_id,
        "slip_image_url": slip_image_url,
        "submitted_at": now,
        "review_status": "pending",
        "reviewed_by_driver_at": None,
        "rejection_reason": None,
    }
    _, ref = db.collection(_SLIPS_COL).add(slip_doc)
    slip_doc["id"] = ref.id

    # Update booking to payment_uploaded — driver will review and confirm
    db.collection(_BOOKINGS_COL).document(booking_id).update({"status": "payment_uploaded"})

    return slip_doc


def get_payment_slip(booking_id: str) -> dict:
    db = get_firestore_client()
    docs = list(
        db.collection(_SLIPS_COL)
        .where(filter=FieldFilter("booking_id", "==", booking_id))
        .stream()
    )
    if not docs:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No payment slip found.")
    # Pick the most recently submitted slip without requiring a composite index
    latest = max(docs, key=lambda d: (d.to_dict() or {}).get("submitted_at") or datetime.min)
    data = latest.to_dict() or {}
    data["id"] = latest.id
    return data


def verify_payment_slip(booking_id: str, driver_id: str) -> dict:
    db = get_firestore_client()
    booking = _get_booking_or_404(db, booking_id)

    if booking.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    slip = get_payment_slip(booking_id)
    now = datetime.now(timezone.utc)

    db.collection(_SLIPS_COL).document(slip["id"]).update({
        "review_status": "approved",
        "reviewed_by_driver_at": now,
    })

    # Confirm the booking
    from services.booking_service import approve_booking
    approve_booking(booking_id, driver_id)

    slip["review_status"] = "approved"
    slip["reviewed_by_driver_at"] = now
    return slip


def reject_payment_slip(booking_id: str, driver_id: str, rejection_reason: str) -> dict:
    db = get_firestore_client()
    booking = _get_booking_or_404(db, booking_id)

    if booking.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    slip = get_payment_slip(booking_id)
    now = datetime.now(timezone.utc)

    db.collection(_SLIPS_COL).document(slip["id"]).update({
        "review_status": "rejected",
        "reviewed_by_driver_at": now,
        "rejection_reason": rejection_reason,
    })

    # Reset booking so passenger can re-upload
    db.collection(_BOOKINGS_COL).document(booking_id).update({"status": "booking_approved"})

    slip["review_status"] = "rejected"
    slip["rejection_reason"] = rejection_reason
    slip["reviewed_by_driver_at"] = now
    return slip


def mark_trip_paid(
    session_id: str,
    booking_id: str,
    driver_id: str,
    trip_date: str,
    amount: float,
    payment_method: str,
) -> dict:
    db = get_firestore_client()
    booking = _get_booking_or_404(db, booking_id)

    if booking.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking.")

    now = datetime.now(timezone.utc)
    payment_doc = {
        "booking_id": booking_id,
        "ride_session_id": session_id,
        "trip_date": trip_date,
        "amount": amount,
        "payment_method": payment_method,
        "paid_at": now,
        "marked_by_driver": driver_id,
    }
    _, ref = db.collection(_TRIP_PAYMENTS_COL).add(payment_doc)
    payment_doc["id"] = ref.id
    return payment_doc


def list_trip_payments(session_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = db.collection(_TRIP_PAYMENTS_COL).where(
        filter=FieldFilter("ride_session_id", "==", session_id)
    ).stream()
    results = []
    for doc in docs:
        d = doc.to_dict() or {}
        d["id"] = doc.id
        results.append(d)
    return results
