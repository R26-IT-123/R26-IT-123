from fastapi import APIRouter, Depends, status

from schemas.sharing import GpsTickRequest, StartSharingRequest, StopSharingRequest, SharingResponse
from services.auth import get_current_user
from services.sharing_service import start_sharing, stop_sharing, update_gps_tick

router = APIRouter(prefix="/api/flts/sharing", tags=["flts-sharing"])


@router.post("/start", response_model=SharingResponse, status_code=status.HTTP_200_OK)
def start(
    payload: StartSharingRequest,
    current_user: dict = Depends(get_current_user),
) -> SharingResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = start_sharing(
        uid=current_user["uid"],
        display_name=display_name,
        route_id=payload.route_id,
        lat=payload.lat,
        lng=payload.lng,
        vehicle_number=payload.vehicle_number,
    )
    return SharingResponse(**result)


@router.post("/tick", response_model=SharingResponse, status_code=status.HTTP_200_OK)
def tick(
    payload: GpsTickRequest,
    current_user: dict = Depends(get_current_user),
) -> SharingResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = update_gps_tick(
        uid=current_user["uid"],
        display_name=display_name,
        route_id=payload.route_id,
        lat=payload.lat,
        lng=payload.lng,
        vehicle_number=payload.vehicle_number,
    )
    return SharingResponse(**result)


@router.post("/stop", response_model=SharingResponse, status_code=status.HTTP_200_OK)
def stop(
    payload: StopSharingRequest,
    current_user: dict = Depends(get_current_user),
) -> SharingResponse:
    display_name = current_user.get("name") or current_user.get("email", "Student")
    result = stop_sharing(
        uid=current_user["uid"],
        display_name=display_name,
        route_id=payload.route_id,
    )
    return SharingResponse(message=result["message"], route_id=payload.route_id)
