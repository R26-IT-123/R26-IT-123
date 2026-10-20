from __future__ import annotations

from fastapi import APIRouter, Depends

from schemas.feedback import DriverRatingProfile, FeedbackEntryOut, FeedbackOut, FeedbackSubmit, RideSummaryOut
from services import feedback_service
from services.auth import get_current_user

router = APIRouter(prefix="/api/routesharing/feedback", tags=["routesharing-feedback"])


@router.post("", response_model=FeedbackOut, status_code=201)
def submit_feedback(data: FeedbackSubmit, user: dict = Depends(get_current_user)) -> FeedbackOut:
    return FeedbackOut(**feedback_service.submit_feedback(user["uid"], data))


@router.post("/sessions/{session_id}/summary", response_model=RideSummaryOut, status_code=201)
def generate_summary(session_id: str, _: dict = Depends(get_current_user)) -> RideSummaryOut:
    return RideSummaryOut(**feedback_service.generate_ai_summary(session_id))


@router.get("/driver/{driver_id}", response_model=DriverRatingProfile)
def get_driver_profile(driver_id: str, _: dict = Depends(get_current_user)) -> DriverRatingProfile:
    return DriverRatingProfile(**feedback_service.get_driver_rating_profile(driver_id))


@router.post("/driver/{driver_id}/refresh-summary", status_code=200)
def refresh_driver_summary(driver_id: str, _: dict = Depends(get_current_user)) -> dict:
    from services.firebase import get_firestore_client
    db = get_firestore_client()
    feedback_service._regenerate_driver_summary(db, driver_id)
    return {"status": "ok"}


@router.get("/driver/{driver_id}/entries", response_model=list[FeedbackEntryOut])
def get_driver_entries(driver_id: str, _: dict = Depends(get_current_user)) -> list[FeedbackEntryOut]:
    return [FeedbackEntryOut(**e) for e in feedback_service.get_driver_feedback_entries(driver_id)]


@router.get("/route/{route_id}/summary", response_model=RideSummaryOut)
def get_route_summary(route_id: str, _: dict = Depends(get_current_user)) -> RideSummaryOut:
    return RideSummaryOut(**feedback_service.get_route_latest_summary(route_id))

#I checked the codes