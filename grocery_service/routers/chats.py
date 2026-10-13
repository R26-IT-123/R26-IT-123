from fastapi import APIRouter, Depends, status

from schemas.chat import ChatItem, CloseChatResponse, DeleteMessageResponse, MessageResponse, SendMessageRequest
from services.auth import get_current_user
from services.chat_service import close_chat, delete_message, get_messages, get_my_chats, send_message

router = APIRouter(prefix="/api/grocery/chats", tags=["grocery-chats"])


@router.get("", response_model=list[ChatItem], status_code=status.HTTP_200_OK)
def my_chats(
    current_user: dict = Depends(get_current_user),
) -> list[ChatItem]:
    items = get_my_chats(uid=current_user["uid"])
    return [ChatItem(**item) for item in items]


@router.get(
    "/{chat_id}/messages",
    response_model=list[MessageResponse],
    status_code=status.HTTP_200_OK,
)
def messages(
    chat_id: str,
    current_user: dict = Depends(get_current_user),
) -> list[MessageResponse]:
    items = get_messages(chat_id=chat_id, uid=current_user["uid"])
    return [MessageResponse(**item) for item in items]


@router.post(
    "/{chat_id}/messages",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
)
def send(
    chat_id: str,
    payload: SendMessageRequest,
    current_user: dict = Depends(get_current_user),
) -> MessageResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = send_message(
        chat_id=chat_id,
        uid=current_user["uid"],
        display_name=display_name,
        msg_type=payload.type,
        content=payload.content,
        items=payload.items,
        bill_amount=payload.bill_amount,
        bill_note=payload.bill_note,
        bill_image_url=payload.bill_image_url,
        item_image_url=payload.item_image_url,
        image_url=payload.image_url,
        payment_method=payload.payment_method,
        slip_image_url=payload.slip_image_url,
    )
    return MessageResponse(**result)


@router.delete(
    "/{chat_id}/messages/{message_id}",
    response_model=DeleteMessageResponse,
    status_code=status.HTTP_200_OK,
)
def delete_msg(
    chat_id: str,
    message_id: str,
    current_user: dict = Depends(get_current_user),
) -> DeleteMessageResponse:
    result = delete_message(chat_id=chat_id, message_id=message_id, uid=current_user["uid"])
    return DeleteMessageResponse(**result)


@router.delete(
    "/{chat_id}",
    response_model=CloseChatResponse,
    status_code=status.HTTP_200_OK,
)
def close(
    chat_id: str,
    current_user: dict = Depends(get_current_user),
) -> CloseChatResponse:
    result = close_chat(chat_id=chat_id, uid=current_user["uid"])
    return CloseChatResponse(**result)
