from fastapi import APIRouter, Depends, status

from schemas.item_request import (
    CloseItemRequestResponse,
    ContactRequesterResponse,
    CreateItemRequestRequest,
    ItemRequestResponse,
)
from services.auth import get_current_user
from services.item_request_service import (
    close_item_request,
    contact_requester,
    create_item_request,
    list_item_requests,
    list_my_item_requests,
)

router = APIRouter(prefix="/api/grocery/item-requests", tags=["grocery-item-requests"])


@router.post("", response_model=ItemRequestResponse, status_code=status.HTTP_201_CREATED)
def create(
    payload: CreateItemRequestRequest,
    current_user: dict = Depends(get_current_user),
) -> ItemRequestResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = create_item_request(
        uid=current_user["uid"],
        display_name=display_name,
        supermarket=payload.supermarket,
        items=payload.items,
        note=payload.note,
    )
    return ItemRequestResponse(**result)


@router.get("/mine", response_model=list[ItemRequestResponse], status_code=status.HTTP_200_OK)
def my_requests(
    current_user: dict = Depends(get_current_user),
) -> list[ItemRequestResponse]:
    items = list_my_item_requests(uid=current_user["uid"])
    return [ItemRequestResponse(**item) for item in items]


@router.get("", response_model=list[ItemRequestResponse], status_code=status.HTTP_200_OK)
def list_open(
    current_user: dict = Depends(get_current_user),
) -> list[ItemRequestResponse]:
    items = list_item_requests()
    return [ItemRequestResponse(**item) for item in items]


@router.post(
    "/{request_id}/contact",
    response_model=ContactRequesterResponse,
    status_code=status.HTTP_201_CREATED,
)
def contact(
    request_id: str,
    current_user: dict = Depends(get_current_user),
) -> ContactRequesterResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = contact_requester(
        request_id=request_id,
        shopper_id=current_user["uid"],
        shopper_name=display_name,
    )
    return ContactRequesterResponse(**result)


@router.delete(
    "/{request_id}",
    response_model=CloseItemRequestResponse,
    status_code=status.HTTP_200_OK,
)
def close(
    request_id: str,
    current_user: dict = Depends(get_current_user),
) -> CloseItemRequestResponse:
    result = close_item_request(request_id=request_id, uid=current_user["uid"])
    return CloseItemRequestResponse(**result)
