from __future__ import annotations

from pydantic import BaseModel


class FcmTokenRegister(BaseModel):
    token: str


class NotificationOut(BaseModel):
    id: str
    type: str
    title: str
    body: str
    data: dict
    created_at: str
