from __future__ import annotations

from fastapi import APIRouter, Depends
from fastapi.responses import Response

from schemas.payment import TripPaymentMark, TripPaymentOut
from fastapi import Query
from schemas.ride_session import (
    DriverArrivalSignal,
    DriverLocationUpdate,
    PassengerLocationShare,
    PassengerRideInfo,
    RideSessionOut,
    RideSessionStart,
)
from services import notification_service, payment_service, ride_service
from services.auth import get_current_user

router = APIRouter(prefix="/api/routesharing/ride-sessions", tags=["routesharing-ride-sessions"])


@router.get("/active", response_model=RideSessionOut)
def get_active_session_for_route(
    route_id: str = Query(...),
    _: dict = Depends(get_current_user),
) -> RideSessionOut:
    from fastapi import HTTPException
    session = ride_service.get_active_session_for_route(route_id)
    if not session:
        raise HTTPException(status_code=404, detail="No active session for this route.")
    return RideSessionOut(**session)


@router.post("", response_model=RideSessionOut, status_code=201)
def start_ride(data: RideSessionStart, user: dict = Depends(get_current_user)) -> RideSessionOut:
    session = ride_service.start_ride(data.route_id, user["uid"], data.ride_date)

    # Notify all confirmed passengers
    passenger_ids = session.get("passenger_ids") or []
    if passenger_ids:
        notification_service.broadcast_to_users(
            passenger_ids,
            title="Ride started",
            body="Your driver has started the ride and is on the way. Tap to track live location.",
            data={"session_id": session["id"], "type": "ride_started"},
            actor_id=user["uid"],
        )

    return RideSessionOut(**session)


@router.get("/{session_id}", response_model=RideSessionOut)
def get_session(session_id: str, _: dict = Depends(get_current_user)) -> RideSessionOut:
    return RideSessionOut(**ride_service.get_session(session_id))


@router.post("/{session_id}/end", response_model=RideSessionOut)
def end_ride(session_id: str, user: dict = Depends(get_current_user)) -> RideSessionOut:
    session = ride_service.end_ride(session_id, user["uid"])

    passenger_ids = session.get("passenger_ids") or []
    if passenger_ids:
        notification_service.broadcast_to_users(
            passenger_ids,
            title="You have arrived",
            body="Thank you for riding. Please rate your experience.",
            data={"session_id": session_id, "type": "ride_ended"},
            actor_id=user["uid"],
        )

    return RideSessionOut(**session)


@router.post("/{session_id}/location", status_code=204, response_class=Response)
def update_driver_location(
    session_id: str, body: DriverLocationUpdate, user: dict = Depends(get_current_user)
) -> Response:
    ride_service.update_driver_location(session_id, user["uid"], body.lat, body.lng)
    return Response(status_code=204)


@router.post("/{session_id}/passenger-location", status_code=204, response_class=Response)
def update_passenger_location(
    session_id: str, body: PassengerLocationShare, user: dict = Depends(get_current_user)
) -> Response:
    ride_service.update_passenger_location(session_id, user["uid"], body.lat, body.lng)
    return Response(status_code=204)


@router.get("/{session_id}/passengers", response_model=list[PassengerRideInfo])
def get_passengers(session_id: str, _: dict = Depends(get_current_user)) -> list[PassengerRideInfo]:
    return [PassengerRideInfo(**p) for p in ride_service.get_session_passengers(session_id)]


@router.post("/{session_id}/arrive", status_code=204, response_class=Response)
def signal_arrival(
    session_id: str, body: DriverArrivalSignal, user: dict = Depends(get_current_user)
) -> Response:
    ride_service.signal_driver_arrival(session_id, user["uid"], body.passenger_id)
    return Response(status_code=204)


@router.post("/{session_id}/boarded", status_code=204, response_class=Response)
def confirm_boarded(
    session_id: str, user: dict = Depends(get_current_user)
) -> Response:
    ride_service.confirm_passenger_boarding(session_id, user["uid"])
    return Response(status_code=204)


@router.post("/{session_id}/mark-paid", response_model=TripPaymentOut, status_code=201)
def mark_daily_paid(
    session_id: str, body: TripPaymentMark, user: dict = Depends(get_current_user)
) -> TripPaymentOut:
    payment = payment_service.mark_trip_paid(
        session_id,
        body.booking_id,
        user["uid"],
        body.trip_date,
        body.amount,
        body.payment_method,
    )

    # Notify passenger their payment was marked
    from services.firebase import get_firestore_client
    db = get_firestore_client()
    booking_doc = db.collection("routesharing_bookings").document(body.booking_id).get()
    if booking_doc.exists:
        passenger_id = (booking_doc.to_dict() or {}).get("passenger_id")
        if passenger_id:
            notification_service.send_to_user(
                passenger_id,
                title="Payment recorded",
                body=f"Your payment of LKR {body.amount:.0f} has been recorded by the driver.",
                data={"session_id": session_id, "type": "payment_marked"},
                actor_id=user["uid"],
            )

    return TripPaymentOut(**payment)
