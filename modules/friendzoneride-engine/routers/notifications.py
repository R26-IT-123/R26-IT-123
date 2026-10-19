from __future__ import annotations

from fastapi import APIRouter, Depends

from schemas.notification import FcmTokenRegister, NotificationOut
from services import notification_service
from services.auth import get_current_user

router = APIRouter(prefix="/api/routesharing", tags=["routesharing-notifications"])


@router.post("/fcm-token")
def register_fcm_token(
    body: FcmTokenRegister,
    user: dict = Depends(get_current_user),
) -> dict:
    notification_service.save_token(user["uid"], body.token)
    return {"message": "Token registered."}


@router.get("/notifications", response_model=list[NotificationOut])
def list_my_notifications(
    user: dict = Depends(get_current_user),
) -> list[NotificationOut]:
    items = notification_service.list_notifications(uid=user["uid"])
    return [NotificationOut(**item) for item in items]

#Cheked by me