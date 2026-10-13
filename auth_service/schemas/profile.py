from typing import Optional

from pydantic import BaseModel


class ProfileResponse(BaseModel):
    uid: str
    full_name: str
    university_email: str
    student_id: str
    faculty: str
    year: int
    semester: int
    contact_number: str
    photo_url: Optional[str] = None
    preferred_route_id: Optional[str] = None
    email_verified: Optional[bool] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    contact_number: Optional[str] = None
    year: Optional[int] = None
    semester: Optional[int] = None
    preferred_route_id: Optional[str] = None


class PhotoUploadResponse(BaseModel):
    photo_url: str
    message: str
