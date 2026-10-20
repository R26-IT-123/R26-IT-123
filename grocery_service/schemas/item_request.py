from pydantic import BaseModel, field_validator


class CreateItemRequestRequest(BaseModel):
    supermarket: str
    items: list[dict]
    note: str = ""

    @field_validator("supermarket")
    @classmethod
    def supermarket_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Supermarket name cannot be empty.")
        return v

    @field_validator("items")
    @classmethod
    def items_not_empty(cls, v: list) -> list:
        if not v:
            raise ValueError("At least one item is required.")
        return v


class ItemRequestResponse(BaseModel):
    id: str
    requester_id: str
    requester_name: str
    supermarket: str
    items: list[dict]
    note: str
    status: str
    created_at: str
    expires_at: str


class CloseItemRequestResponse(BaseModel):
    message: str
    id: str


class ContactRequesterResponse(BaseModel):
    message: str
    chat_id: str
