from __future__ import annotations

from fastapi import APIRouter, Depends

from schemas.payment import PaymentSlipOut, PaymentSlipSubmit, SlipReject, TripPaymentMark, TripPaymentOut
from services import notification_service, payment_service
from services.auth import get_current_user
from services.firebase import get_firestore_client

router = APIRouter(prefix="/api/routesharing", tags=["routesharing-payments"])

_BOOKINGS_COL = "routesharing_bookings"


def _passenger_id_for_booking(booking_id: str) -> str | None:
    db = get_firestore_client()
    doc = db.collection(_BOOKINGS_COL).document(booking_id).get()
    return (doc.to_dict() or {}).get("passenger_id") if doc.exists else None


def _driver_id_for_booking(booking_id: str) -> str | None:
    db = get_firestore_client()
    doc = db.collection(_BOOKINGS_COL).document(booking_id).get()
    return (doc.to_dict() or {}).get("driver_id") if doc.exists else None


@router.post("/bookings/{booking_id}/payment-slip", response_model=PaymentSlipOut, status_code=201)
def submit_payment_slip(
    booking_id: str, body: PaymentSlipSubmit, user: dict = Depends(get_current_user)
) -> PaymentSlipOut:
    slip = payment_service.submit_payment_slip(booking_id, user["uid"], body.slip_image_url)

    driver_id = _driver_id_for_booking(booking_id)
    if driver_id:
        notification_service.send_to_user(
            driver_id,
            title="Payment slip submitted",
            body="A passenger has submitted a payment slip for verification.",
            data={"booking_id": booking_id, "type": "slip_submitted"},
            actor_id=user["uid"],
        )

    return PaymentSlipOut(**slip)


@router.get("/bookings/{booking_id}/payment-slip", response_model=PaymentSlipOut)
def get_payment_slip(booking_id: str, _: dict = Depends(get_current_user)) -> PaymentSlipOut:
    return PaymentSlipOut(**payment_service.get_payment_slip(booking_id))


@router.post("/bookings/{booking_id}/payment-slip/verify", response_model=PaymentSlipOut)
def verify_slip(booking_id: str, user: dict = Depends(get_current_user)) -> PaymentSlipOut:
    slip = payment_service.verify_payment_slip(booking_id, user["uid"])

    passenger_id = _passenger_id_for_booking(booking_id)
    if passenger_id:
        notification_service.send_to_user(
            passenger_id,
            title="Payment verified — seat confirmed",
            body="Your payment was verified. Your seat is now reserved!",
            data={"booking_id": booking_id, "type": "payment_verified"},
            actor_id=user["uid"],
        )

    return PaymentSlipOut(**slip)


@router.post("/bookings/{booking_id}/payment-slip/reject", response_model=PaymentSlipOut)
def reject_slip(booking_id: str, body: SlipReject, user: dict = Depends(get_current_user)) -> PaymentSlipOut:
    slip = payment_service.reject_payment_slip(booking_id, user["uid"], body.rejection_reason)

    passenger_id = _passenger_id_for_booking(booking_id)
    if passenger_id:
        notification_service.send_to_user(
            passenger_id,
            title="Payment slip rejected",
            body=f"Your payment slip was rejected: {body.rejection_reason}. Please re-upload.",
            data={"booking_id": booking_id, "type": "slip_rejected"},
            actor_id=user["uid"],
        )

    return PaymentSlipOut(**slip)
