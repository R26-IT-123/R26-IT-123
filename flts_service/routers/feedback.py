from fastapi import APIRouter, Depends, Query, status

from schemas.feedback import FeedbackItem, FeedbackRequest, FeedbackResponse
from services.auth import get_current_user
from services.feedback_service import get_feedback, submit_feedback

router = APIRouter(prefix="/api/flts/feedback", tags=["flts-feedback"])


@router.get("", response_model=list[FeedbackItem], status_code=status.HTTP_200_OK)
def list_feedback(
    vehicle_number: str = Query(..., description="Vehicle registration number"),
    current_user: dict = Depends(get_current_user),
) -> list[FeedbackItem]:
    items = get_feedback(vehicle_number=vehicle_number.strip().upper())
    return [FeedbackItem(**item) for item in items]


@router.post("", response_model=FeedbackResponse, status_code=status.HTTP_201_CREATED)
def submit(
    payload: FeedbackRequest,
    current_user: dict = Depends(get_current_user),
) -> FeedbackResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = submit_feedback(
        uid=current_user["uid"],
        display_name=display_name,
        vehicle_number=payload.vehicle_number,
        route_id=payload.route_id,
        rating=payload.rating,
        feedback_type=payload.type,
        comment=payload.comment,
    )
    return FeedbackResponse(**result)
