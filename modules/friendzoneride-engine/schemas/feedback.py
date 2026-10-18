from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class FeedbackSubmit(BaseModel):
    ride_session_id: str
    driver_id: str
    overall_rating: float = Field(ge=1, le=5)
    comment: str = Field(min_length=1, max_length=500)


class FeedbackOut(BaseModel):
    id: str
    ride_session_id: str
    passenger_id: str
    driver_id: str
    overall_rating: float
    comment: str
    submitted_at: datetime | None


class FeedbackEntryOut(BaseModel):
    id: str
    overall_rating: float
    comment: str
    submitted_at: datetime | None


class RideSummaryOut(BaseModel):
    id: str
    ride_session_id: str
    driver_id: str
    ai_summary: str
    avg_rating: float
    generated_at: datetime | None


class DriverRatingProfile(BaseModel):
    driver_id: str
    overall_avg_rating: float
    total_rides: int
    ai_summary: str | None = None
    recent_summaries: list[RideSummaryOut]
    last_updated: datetime | None
