from datetime import datetime, timezone

from fastapi import HTTPException, UploadFile, status

from services.firebase import get_firestore_client, get_storage_bucket

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
_USERS_COLLECTION = "users"


def get_profile(uid: str) -> dict:
    db = get_firestore_client()
    doc = db.collection(_USERS_COLLECTION).document(uid).get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found.",
        )

    data = doc.to_dict() or {}
    data["uid"] = uid
    return data


def update_profile(uid: str, updates: dict) -> dict:
    db = get_firestore_client()
    doc_ref = db.collection(_USERS_COLLECTION).document(uid)

    if not doc_ref.get().exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found.",
        )

    updates["updated_at"] = datetime.now(timezone.utc).isoformat()
    doc_ref.update(updates)
    return get_profile(uid)


async def upload_profile_photo(uid: str, file: UploadFile) -> str:
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG, PNG, and WebP images are supported.",
        )

    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size must not exceed 5 MB.",
        )

    ext = (file.filename or "photo").rsplit(".", 1)[-1].lower()
    if ext not in ("jpg", "jpeg", "png", "webp"):
        ext = "jpg"

    bucket = get_storage_bucket()
    blob = bucket.blob(f"profile_photos/{uid}/profile.{ext}")
    blob.upload_from_string(content, content_type=file.content_type)
    blob.make_public()

    photo_url = blob.public_url

    db = get_firestore_client()
    db.collection(_USERS_COLLECTION).document(uid).update({
        "photo_url": photo_url,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    })

    return photo_url
