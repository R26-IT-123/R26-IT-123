from __future__ import annotations

from fastapi import APIRouter, Depends

from schemas.booking import (
    AbsenceNotification,
    BookingApprove,
    BookingCreate,
    BookingDecline,
    BookingOut,
    FareBreakdown,
)
from services import booking_service, notification_service
from services.auth import get_current_user
from services.firebase import get_firestore_client

router = APIRouter(prefix="/api/routesharing/bookings", tags=["routesharing-bookings"])


@router.post("", response_model=BookingOut, status_code=201)
def create_booking(data: BookingCreate, user: dict = Depends(get_current_user)) -> BookingOut:
    booking = booking_service.create_booking(user["uid"], data)

    # Notify driver of new booking request
    notification_service.send_to_user(
        booking["driver_id"],
        title="New booking request",
        body=f"You have a new {data.booking_type} booking request. Tap to review.",
        data={"booking_id": booking["id"], "type": "booking_request"},
        actor_id=user["uid"],
    )

    return BookingOut(**booking)


@router.get("", response_model=list[BookingOut])
def list_my_bookings(user: dict = Depends(get_current_user)) -> list[BookingOut]:
    bookings = booking_service.list_bookings_for_passenger(user["uid"])
    return [BookingOut(**b) for b in bookings]


@router.get("/driver", response_model=list[BookingOut])
def list_driver_bookings(user: dict = Depends(get_current_user)) -> list[BookingOut]:
    bookings = booking_service.list_bookings_for_driver(user["uid"])
    return [BookingOut(**b) for b in bookings]


@router.get("/{booking_id}", response_model=BookingOut)
def get_booking(booking_id: str, _: dict = Depends(get_current_user)) -> BookingOut:
    return BookingOut(**booking_service.get_booking(booking_id))


@router.get("/{booking_id}/fare", response_model=FareBreakdown)
def get_fare(booking_id: str, _: dict = Depends(get_current_user)) -> FareBreakdown:
    return FareBreakdown(**booking_service.get_fare_breakdown(booking_id))


@router.post("/{booking_id}/approve", response_model=BookingOut)
def approve_booking(booking_id: str, body: BookingApprove, user: dict = Depends(get_current_user)) -> BookingOut:
    booking = booking_service.approve_booking(booking_id, user["uid"], body.note)

    if booking["status"] == "booking_approved":
        notification_service.send_to_user(
            booking["passenger_id"],
            title="Booking accepted!",
            body="Please upload your payment slip within 2 days to confirm your seat.",
            data={"booking_id": booking_id, "type": "payment_required"},
            actor_id=user["uid"],
        )
    else:
        notification_service.send_to_user(
            booking["passenger_id"],
            title="Seat confirmed!",
            body="Your payment was verified. Your seat is now reserved!",
            data={"booking_id": booking_id, "type": "booking_confirmed"},
            actor_id=user["uid"],
        )

    return BookingOut(**booking)


@router.post("/{booking_id}/decline", response_model=BookingOut)
def decline_booking(booking_id: str, body: BookingDecline, user: dict = Depends(get_current_user)) -> BookingOut:
    booking = booking_service.decline_booking(booking_id, user["uid"], body.reason)

    notification_service.send_to_user(
        booking["passenger_id"],
        title="Booking declined",
        body=f"Your booking request was declined. {body.reason or ''}".strip(),
        data={"booking_id": booking_id, "type": "booking_declined"},
        actor_id=user["uid"],
    )

    return BookingOut(**booking)


@router.post("/{booking_id}/request-payment", response_model=BookingOut)
def request_payment(booking_id: str, user: dict = Depends(get_current_user)) -> BookingOut:
    booking = booking_service.request_payment(booking_id, user["uid"])

    notification_service.send_to_user(
        booking["passenger_id"],
        title="Payment required",
        body="Please upload your payment slip to confirm your weekly booking.",
        data={"booking_id": booking_id, "type": "payment_required"},
        actor_id=user["uid"],
    )

    return BookingOut(**booking)


@router.post("/{booking_id}/absence")
def notify_absence(
    booking_id: str, body: AbsenceNotification, user: dict = Depends(get_current_user)
) -> dict:
    absence = booking_service.notify_absence(booking_id, user["uid"], body.ride_date, body.reason)

    passenger_name = absence.get("passenger_name") or "A passenger"
    route_from = absence.get("route_start_address")
    route_to = absence.get("route_destination")
    route_line = f"\nRoute: {route_from} → {route_to}" if route_from and route_to else ""

    notification_service.send_to_user(
        absence["driver_id"],
        title="Passenger absence",
        body=f"{passenger_name} cannot make it on {body.ride_date}. Seat may be temporarily available.{route_line}",
        data={
            "booking_id": booking_id,
            "ride_date": body.ride_date,
            "type": "passenger_absence",
            "passenger_name": passenger_name,
            "route_start_address": route_from,
            "route_destination": route_to,
        },
        actor_id=user["uid"],
    )

    return absence
