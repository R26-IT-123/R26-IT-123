from pydantic import BaseModel


class SendRequestResponse(BaseModel):
    message: str
    chat_id: str
    request_id: str


class RequestItem(BaseModel):
    id: str
    announcement_id: str
    requester_id: str
    requester_name: str
    shopper_id: str
    chat_id: str
    status: str
    created_at: str
