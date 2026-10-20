from fastapi import Header, HTTPException, status

from services.firebase import get_auth_client


def get_current_user(authorization: str = Header(...)) -> dict:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing Bearer token.")

    id_token = authorization.removeprefix("Bearer ").strip()
    if not id_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Empty Firebase ID token.")

    try:
        return get_auth_client().verify_id_token(id_token)
    except Exception as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Firebase ID token: {error}",
        ) from error
