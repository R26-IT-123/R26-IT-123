from pydantic import BaseModel, field_validator


class StartSharingRequest(BaseModel):
    route_id: str
    lat: float
    lng: float
    vehicle_number: str = ""

    @field_validator("lat")
    @classmethod
    def validate_lat(cls, v: float) -> float:
        if not -90 <= v <= 90:
            raise ValueError("Latitude must be between -90 and 90.")
        return v

    @field_validator("lng")
    @classmethod
    def validate_lng(cls, v: float) -> float:
        if not -180 <= v <= 180:
            raise ValueError("Longitude must be between -180 and 180.")
        return v


class GpsTickRequest(BaseModel):
    route_id: str
    lat: float
    lng: float
    vehicle_number: str = ""

    @field_validator("lat")
    @classmethod
    def validate_lat(cls, v: float) -> float:
        if not -90 <= v <= 90:
            raise ValueError("Latitude must be between -90 and 90.")
        return v

    @field_validator("lng")
    @classmethod
    def validate_lng(cls, v: float) -> float:
        if not -180 <= v <= 180:
            raise ValueError("Longitude must be between -180 and 180.")
        return v


class StopSharingRequest(BaseModel):
    route_id: str


class SharingResponse(BaseModel):
    message: str
    route_id: str
