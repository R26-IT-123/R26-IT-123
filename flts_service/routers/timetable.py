from fastapi import APIRouter, Depends, Query

from schemas.timetable import TimetableEntryResponse
from services.auth import get_current_user
from services.timetable_service import list_timetables

router = APIRouter(prefix="/api/flts/timetable", tags=["flts-timetable"])


@router.get("", response_model=list[TimetableEntryResponse])
def get_timetables(
    origin: str | None = Query(default=None),
    destination: str | None = Query(default=None),
    route_number: str | None = Query(default=None),
    _: dict = Depends(get_current_user),
) -> list[TimetableEntryResponse]:
    return [
        TimetableEntryResponse(**e)
        for e in list_timetables(origin, destination, route_number)
    ]
