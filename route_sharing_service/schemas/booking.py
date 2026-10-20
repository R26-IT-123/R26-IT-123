from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

BookingType = Literal["weekly", "daily"]


class BookingCreate(BaseModel):
    route_id: str
    booking_type: BookingType
    days_selected: list[str] = Field(min_length=1, max_length=7)
    pickup_lat: float | None = None
    pickup_lng: float | None = None
    pickup_address: str | None = None
    add_friend_seat: bool = False
    friend_name: str | None = None
    friend_contact: str | None = None  # phone or university email
    friend_pickup_lat: float | None = None
    friend_pickup_lng: float | None = None
    friend_pickup_address: str | None = None


class BookingOut(BaseModel):
    id: str
    passenger_id: str
    route_id: str
    driver_id: str
    booking_type: str
    days_selected: list[str]
    fare_amount: float
    status: str
    hold_expires_at: datetime | None = None
    created_at: datetime | None = None
    priority: bool = False
    seat_number: int | None = None
    adjusted_fare: float | None = None  # if intermediate pickup
    pickup_distance_km: float | None = None
    passenger_year: int | None = None
    friend_fare_amount: float | None = None


class FareBreakdown(BaseModel):
    route_distance_km: float | None = None
    pickup_distance_km: float | None = None
    price_per_trip: float
    price_per_km: float | None = None
    days_count: int
    booking_type: str
    discount_pct: float
    discount_amount: float
    total_fare: float
    payment_type: str  # "upfront" | "post-ride"
    friend_seat_subtotal: float | None = None
    combined_total: float | None = None
    pickme_equivalent: float | None = None
    saving_vs_pickme: float | None = None


class BookingApprove(BaseModel):
    note: str | None = None


class BookingDecline(BaseModel):
    reason: str | None = None


class AbsenceNotification(BaseModel):
    ride_date: str  # "YYYY-MM-DD"
    reason: str | None = None
