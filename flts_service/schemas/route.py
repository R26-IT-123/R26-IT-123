from typing import Optional
from pydantic import BaseModel


class BusStop(BaseModel):
    id: str
    name: str
    lat: float
    lng: float


class BusRoute(BaseModel):
    id: str
    destination: str
    stops: list[BusStop]
    active_passengers: int = 0


class PassengersResponse(BaseModel):
    route_id: str
    active_count: int
    passengers: list[dict]
    centroid_lat: Optional[float] = None
    centroid_lng: Optional[float] = None
