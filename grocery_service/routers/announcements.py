from fastapi import APIRouter, Depends, status

from schemas.announcement import (
    AnnouncementResponse,
    CloseAnnouncementResponse,
    CreateAnnouncementRequest,
)
from services.auth import get_current_user
from services.announcement_service import (
    close_announcement,
    create_announcement,
    list_announcements,
)

router = APIRouter(prefix="/api/grocery/announcements", tags=["grocery-announcements"])


@router.post("", response_model=AnnouncementResponse, status_code=status.HTTP_201_CREATED)
def create(
    payload: CreateAnnouncementRequest,
    current_user: dict = Depends(get_current_user),
) -> AnnouncementResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = create_announcement(
        uid=current_user["uid"],
        display_name=display_name,
        supermarket=payload.supermarket,
        message=payload.message,
    )
    return AnnouncementResponse(**result)


@router.get("", response_model=list[AnnouncementResponse], status_code=status.HTTP_200_OK)
def list_active(
    current_user: dict = Depends(get_current_user),
) -> list[AnnouncementResponse]:
    items = list_announcements()
    return [AnnouncementResponse(**item) for item in items]


@router.delete(
    "/{announcement_id}",
    response_model=CloseAnnouncementResponse,
    status_code=status.HTTP_200_OK,
)
def close(
    announcement_id: str,
    current_user: dict = Depends(get_current_user),
) -> CloseAnnouncementResponse:
    result = close_announcement(announcement_id=announcement_id, uid=current_user["uid"])
    return CloseAnnouncementResponse(**result)
