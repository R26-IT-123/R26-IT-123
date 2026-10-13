from fastapi import APIRouter, Depends, status

from schemas.notification import NotificationResponse
from services.auth import get_current_user
from services.notification_service import list_notifications

router = APIRouter(prefix="/api/grocery/notifications", tags=["grocery-notifications"])


@router.get("", response_model=list[NotificationResponse], status_code=status.HTTP_200_OK)
def list_mine(
    current_user: dict = Depends(get_current_user),
) -> list[NotificationResponse]:
    items = list_notifications(uid=current_user["uid"])
    return [NotificationResponse(**item) for item in items]
