from pydantic import BaseModel


class NotificationResponse(BaseModel):
    id: str
    type: str
    title: str
    body: str
    data: dict
    created_at: str
