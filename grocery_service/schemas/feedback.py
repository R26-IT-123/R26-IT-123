from pydantic import BaseModel, Field


class FeedbackCreate(BaseModel):
    chat_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: str = ""


class RecentRating(BaseModel):
    rating: int
    comment: str
    created_at: str


class TrustProfile(BaseModel):
    uid: str
    avg_rating: float
    total_ratings: int
    shopper_avg: float
    shopper_count: int
    requester_avg: float
    requester_count: int
    completed_trips: int
    badges: list[str]
    recent_ratings: list[RecentRating]


class FeedbackResponse(BaseModel):
    id: str
    from_user_id: str
    to_user_id: str
    chat_id: str
    rating: int
    comment: str
    to_user_role: str
    created_at: str
