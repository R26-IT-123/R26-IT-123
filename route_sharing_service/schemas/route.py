from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field


class Location(BaseModel):
    lat: float
    lng: float
    address: str | None = None


class Waypoint(BaseModel):
    address: str
    lat: float | None = None
    lng: float | None = None
    order: int


class RouteCreate(BaseModel):
    start_location: Location
    destination: str
    destination_lat: float | None = None
    destination_lng: float | None = None
    stop_location: Location | None = None
    waypoints: list[Waypoint] = []
    start_date: date
    departure_time: str  # "HH:MM"
    total_seats: int = Field(ge=3, le=4)
    vehicle_type: str | None = None


class RouteUpdate(BaseModel):
    departure_time: str | None = None
    total_seats: int | None = Field(None, ge=3, le=4)
    vehicle_type: str | None = None
    status: Literal["active", "inactive"] | None = None


class RouteOut(BaseModel):
    id: str
    driver_id: str
    start_location: dict
    destination: str
    stop_location: dict | None = None
    route_polyline: str | None = None
    total_distance_km: float | None = None
    start_date: str | None = None
    end_date: str | None = None
    departure_time: str
    total_seats: int
    seats_available: int
    price_per_trip: float
    price_per_km: float | None = None
    status: str
    waypoints: list[dict] = []
    driver_name: str | None = None
    driver_year: int | None = None
    avg_rating: float | None = None
    ai_summary: str | None = None
    created_at: datetime | None = None


class PricingSuggestion(BaseModel):
    distance_km: float
    suggested_min_fare: float
    suggested_max_fare: float
    rate_per_km_min: float
    rate_per_km_max: float
    platform_set_fare: float | None = None
    price_per_km: float | None = None
    pickme_equivalent: float


class DriverProfileUpdate(BaseModel):
    is_driver: bool | None = None
    home_location: Location | None = None
    regular_destination: str | None = None
    usual_departure_time: str | None = None
    vehicle_type: str | None = None
    vehicle_seats: int | None = Field(None, ge=3, le=4)


class StandbyJoin(BaseModel):
    route_id: str
