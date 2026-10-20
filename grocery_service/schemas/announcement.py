from pydantic import BaseModel, field_validator


class CreateAnnouncementRequest(BaseModel):
    supermarket: str
    message: str = ""

    @field_validator("supermarket")
    @classmethod
    def supermarket_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Supermarket name cannot be empty.")
        return v


class AnnouncementResponse(BaseModel):
    id: str
    shopper_id: str
    shopper_name: str
    supermarket: str
    message: str
    status: str
    created_at: str
    expires_at: str


class CloseAnnouncementResponse(BaseModel):
    message: str
    id: str
