from pydantic import BaseModel, Field


class NotifyRequest(BaseModel):
    sender_name: str = Field(..., min_length=1, max_length=100)
    text: str = Field(..., min_length=1, max_length=2000)


class NotifyResponse(BaseModel):
    status: str
