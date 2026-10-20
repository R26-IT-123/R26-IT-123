import random
import string
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status

from services.firebase import get_firestore_client

OTP_EXPIRY_MINUTES = 5
_COLLECTION = "otp_verifications"


def generate_otp() -> str:
    return "".join(random.choices(string.digits, k=6))


def store_otp(email: str, otp: str, registration_data: dict) -> None:
    db = get_firestore_client()
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)).isoformat()
    db.collection(_COLLECTION).document(email).set({
        "otp": otp,
        "expires_at": expires_at,
        "registration_data": registration_data,
        "created_at": datetime.now(timezone.utc).isoformat(),
    })


def verify_and_consume_otp(email: str, otp: str) -> dict:
    """Validate OTP, delete the record, and return the stored registration data."""
    db = get_firestore_client()
    doc = db.collection(_COLLECTION).document(email).get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No pending registration found for this email. Please register first.",
        )

    data = doc.to_dict() or {}
    expires_at = datetime.fromisoformat(data["expires_at"])

    if datetime.now(timezone.utc) > expires_at:
        db.collection(_COLLECTION).document(email).delete()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has expired. Please register again to get a new code.",
        )

    if data["otp"] != otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP. Please check the code sent to your email.",
        )

    db.collection(_COLLECTION).document(email).delete()
    return data["registration_data"]


def get_pending_registration(email: str) -> dict:
    """Return registration_data for an existing pending OTP record."""
    db = get_firestore_client()
    doc = db.collection(_COLLECTION).document(email).get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No pending registration found for this email.",
        )

    return (doc.to_dict() or {}).get("registration_data", {})
