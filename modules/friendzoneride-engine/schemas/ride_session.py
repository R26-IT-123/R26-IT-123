from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class RideSessionStart(BaseModel):
    route_id: str
    ride_date: str  # "YYYY-MM-DD"


class RideSessionOut(BaseModel):
    id: str
    route_id: str
    driver_id: str
    ride_date: str
    start_time: datetime | None = None
    end_time: datetime | None = None
    status: str  # active / completed / cancelled
    passenger_ids: list[str] = []


class DriverLocationUpdate(BaseModel):
    lat: float
    lng: float


class PassengerLocationShare(BaseModel):
    lat: float
    lng: float


class DriverArrivalSignal(BaseModel):
    passenger_id: str


class PassengerRideInfo(BaseModel):
    passenger_id: str
    booking_id: str | None = None
    passenger_name: str | None = None
    pickup_lat: float | None = None
    pickup_lng: float | None = None
    pickup_address: str | None = None
    pickup_distance_from_start_km: float | None = None
    fare_amount: float
    booking_type: str
    payment_status: str  # pending / paid
