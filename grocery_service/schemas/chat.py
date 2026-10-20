from typing import Optional

from pydantic import BaseModel, field_validator

_ALLOWED_TYPES = {
    "text", "item_list", "bill", "image",
    "payment_intent", "payment_slip",
    "payment_confirmed", "delivery_confirmed", "receipt_confirmed",
}


class SendMessageRequest(BaseModel):
    type: str = "text"
    content: str = ""
    items: Optional[list[dict]] = None
    bill_amount: Optional[float] = None
    bill_note: Optional[str] = None
    bill_image_url: Optional[str] = None
    item_image_url: Optional[str] = None
    image_url: Optional[str] = None
    payment_method: Optional[str] = None
    slip_image_url: Optional[str] = None

    @field_validator("type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        if v not in _ALLOWED_TYPES:
            raise ValueError(f"type must be one of: {', '.join(sorted(_ALLOWED_TYPES))}")
        return v


class MessageResponse(BaseModel):
    id: str
    sender_id: str
    sender_name: str
    type: str
    content: str
    sent_at: str
    items: Optional[list[dict]] = None
    bill_amount: Optional[float] = None
    bill_note: Optional[str] = None
    bill_image_url: Optional[str] = None
    item_image_url: Optional[str] = None
    image_url: Optional[str] = None
    payment_method: Optional[str] = None
    slip_image_url: Optional[str] = None


class ChatItem(BaseModel):
    id: str
    announcement_id: str
    shopper_id: str
    shopper_name: str
    requester_id: str
    requester_name: str
    supermarket: str
    status: str
    payment_status: Optional[str] = None
    last_message: Optional[str] = None
    last_message_at: Optional[str] = None
    created_at: str


class CloseChatResponse(BaseModel):
    message: str
    chat_id: str


class DeleteMessageResponse(BaseModel):
    message: str
    message_id: str
