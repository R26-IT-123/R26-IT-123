from fastapi import APIRouter, Depends

from schemas.feedback import FeedbackCreate, FeedbackResponse, TrustProfile
from services.auth import get_current_user
from services import feedback_service

router = APIRouter(prefix="/api/grocery", tags=["feedback"])


@router.post("/feedback", response_model=FeedbackResponse)
def submit_feedback(body: FeedbackCreate, user=Depends(get_current_user)):
    return feedback_service.submit_feedback(
        from_uid=user["uid"],
        chat_id=body.chat_id,
        rating=body.rating,
        comment=body.comment,
    )


@router.get("/users/{uid}/trust", response_model=TrustProfile)
def get_trust_profile(uid: str, user=Depends(get_current_user)):
    return feedback_service.get_trust_profile(uid)


@router.get("/feedback/chat/{chat_id}/mine")
def check_my_feedback(chat_id: str, user=Depends(get_current_user)):
    return feedback_service.has_submitted_feedback(user["uid"], chat_id)
