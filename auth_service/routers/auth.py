import os
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, HTTPException, status
from firebase_admin.auth import UserNotFoundError

from schemas.auth import (
    LoginRequest,
    LoginResponse,
    OTPVerifyRequest,
    OTPVerifyResponse,
    RegisterRequest,
    RegisterResponse,
    ResendOTPRequest,
)
from services.email import send_otp_email
from services.firebase import get_auth_client, get_firestore_client
from services.otp import generate_otp, get_pending_registration, store_otp, verify_and_consume_otp
from utils.faculty import detect_faculty, extract_student_id

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_200_OK)
def register(payload: RegisterRequest) -> RegisterResponse:
    # Reject if this SLIIT email already has a Firebase Auth account
    try:
        get_auth_client().get_user_by_email(payload.email)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This email is already registered.",
        )
    except HTTPException:
        raise
    except UserNotFoundError:
        pass  # Expected — email is free, proceed
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Could not verify email availability: {e}",
        ) from e

    faculty = detect_faculty(payload.email)
    student_id = extract_student_id(payload.email)

    registration_data = {
        "email": payload.email,
        "password": payload.password,
        "full_name": payload.full_name,
        "contact_number": payload.contact_number,
        "year": payload.year,
        "semester": payload.semester,
        "faculty": faculty,
        "student_id": student_id,
    }

    otp = generate_otp()
    store_otp(payload.email, otp, registration_data)

    try:
        send_otp_email(payload.email, otp, payload.full_name)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send OTP email. Check SMTP configuration. Error: {e}",
        ) from e

    return RegisterResponse(
        message="OTP sent to your SLIIT email. Enter the 6-digit code to complete registration."
    )


@router.post("/verify-otp", response_model=OTPVerifyResponse, status_code=status.HTTP_201_CREATED)
def verify_email_otp(payload: OTPVerifyRequest) -> OTPVerifyResponse:
    reg = verify_and_consume_otp(payload.email, payload.otp)

    try:
        user = get_auth_client().create_user(
            email=reg["email"],
            password=reg["password"],
            display_name=reg["full_name"],
            email_verified=True,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create user account: {e}",
        ) from e

    now = datetime.now(timezone.utc).isoformat()
    get_firestore_client().collection("users").document(user.uid).set({
        "uid": user.uid,
        "full_name": reg["full_name"],
        "university_email": reg["email"],
        "student_id": reg["student_id"],
        "faculty": reg["faculty"],
        "year": reg["year"],
        "semester": reg["semester"],
        "contact_number": reg["contact_number"],
        "photo_url": None,
        "email_verified": True,
        "created_at": now,
        "updated_at": now,
    })

    return OTPVerifyResponse(
        uid=user.uid,
        message="Registration complete. You can now log in.",
        faculty=reg["faculty"],
        student_id=reg["student_id"],
    )


@router.post("/resend-otp", response_model=RegisterResponse, status_code=status.HTTP_200_OK)
def resend_otp(payload: ResendOTPRequest) -> RegisterResponse:
    reg = get_pending_registration(payload.email)

    otp = generate_otp()
    store_otp(payload.email, otp, reg)

    try:
        send_otp_email(payload.email, otp, reg["full_name"])
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to resend OTP email: {e}",
        ) from e

    return RegisterResponse(message="New OTP sent to your SLIIT email.")


@router.post("/login", response_model=LoginResponse, status_code=status.HTTP_200_OK)
def login(payload: LoginRequest) -> LoginResponse:
    api_key = os.getenv("FIREBASE_WEB_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server authentication configuration error.",
        )

    identity_url = (
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}"
    )
    try:
        resp = httpx.post(
            identity_url,
            json={"email": payload.email, "password": payload.password, "returnSecureToken": True},
            timeout=10.0,
        )
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not reach authentication provider.",
        ) from e

    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
        )

    uid = resp.json()["localId"]

    try:
        raw_token = get_auth_client().create_custom_token(uid)
        custom_token = raw_token.decode("utf-8") if isinstance(raw_token, bytes) else raw_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create session token: {e}",
        ) from e

    return LoginResponse(custom_token=custom_token, uid=uid)
