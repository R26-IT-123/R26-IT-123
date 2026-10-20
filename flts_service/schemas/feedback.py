from typing import Optional

from pydantic import BaseModel, field_validator


class FeedbackItem(BaseModel):
    feedback_id: str
    vehicle_number: str
    route_id: str
    display_name: str
    rating: int
    type: str
    comment: str
    timestamp: Optional[str] = None


class FeedbackRequest(BaseModel):
    vehicle_number: str
    route_id: str
    rating: int
    type: str = ""
    comment: str = ""

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v: int) -> int:
        if not 1 <= v <= 5:
            raise ValueError("Rating must be between 1 and 5.")
        return v

    @field_validator("vehicle_number")
    @classmethod
    def validate_vehicle_number(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Vehicle number cannot be empty.")
        return v.strip().upper()


class FeedbackResponse(BaseModel):
    message: str
    feedback_id: str
