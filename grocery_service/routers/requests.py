from fastapi import APIRouter, Depends, status

from schemas.request import RequestItem, SendRequestResponse
from services.auth import get_current_user
from services.request_service import list_requests_for_announcement, send_request

router = APIRouter(prefix="/api/grocery/announcements", tags=["grocery-requests"])


@router.post(
    "/{announcement_id}/requests",
    response_model=SendRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def request_from_announcement(
    announcement_id: str,
    current_user: dict = Depends(get_current_user),
) -> SendRequestResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = send_request(
        announcement_id=announcement_id,
        requester_id=current_user["uid"],
        requester_name=display_name,
    )
    return SendRequestResponse(**result)


@router.get(
    "/{announcement_id}/requests",
    response_model=list[RequestItem],
    status_code=status.HTTP_200_OK,
)
def get_requests(
    announcement_id: str,
    current_user: dict = Depends(get_current_user),
) -> list[RequestItem]:
    items = list_requests_for_announcement(
        announcement_id=announcement_id,
        uid=current_user["uid"],
    )
    return [RequestItem(**item) for item in items]
