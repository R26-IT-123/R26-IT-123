from fastapi import APIRouter, Depends

from schemas.notify import NotifyRequest, NotifyResponse
from services.auth import get_current_user
from services.notify_service import notify_new_message

router = APIRouter(prefix="/api/community-chat", tags=["community-chat"])


@router.post("/notify", response_model=NotifyResponse)
def notify(
    payload: NotifyRequest,
    current_user: dict = Depends(get_current_user),
) -> NotifyResponse:
    notify_new_message(
        sender_name=payload.sender_name,
        text=payload.text,
        exclude_uid=current_user["uid"],
    )
    return NotifyResponse(status="sent")
