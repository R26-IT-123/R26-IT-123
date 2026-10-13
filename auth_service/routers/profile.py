from fastapi import APIRouter, Depends, File, UploadFile

from schemas.profile import PhotoUploadResponse, ProfileResponse, ProfileUpdateRequest
from services.auth import get_current_user
from services.profile import get_profile, update_profile, upload_profile_photo

router = APIRouter(prefix="/api/profile", tags=["profile"])


@router.get("/me", response_model=ProfileResponse)
def get_my_profile(current_user: dict = Depends(get_current_user)) -> ProfileResponse:
    return ProfileResponse(**get_profile(current_user["uid"]))


@router.patch("/me", response_model=ProfileResponse)
def update_my_profile(
    payload: ProfileUpdateRequest,
    current_user: dict = Depends(get_current_user),
) -> ProfileResponse:
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        return ProfileResponse(**get_profile(current_user["uid"]))
    return ProfileResponse(**update_profile(current_user["uid"], updates))


@router.post("/me/photo", response_model=PhotoUploadResponse)
async def upload_photo(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
) -> PhotoUploadResponse:
    photo_url = await upload_profile_photo(current_user["uid"], file)
    return PhotoUploadResponse(
        photo_url=photo_url,
        message="Profile photo updated successfully.",
    )
