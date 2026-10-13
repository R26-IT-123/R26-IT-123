from fastapi import APIRouter, Depends, status

from schemas.incident import IncidentResponse, ReportIncidentRequest, ResolveIncidentResponse
from services.auth import get_current_user
from services.incident_service import get_route_incidents, report_incident, resolve_incident

router = APIRouter(prefix="/api/flts/incidents", tags=["flts-incidents"])


@router.post("", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
def report(
    payload: ReportIncidentRequest,
    current_user: dict = Depends(get_current_user),
) -> IncidentResponse:
    result = report_incident(
        uid=current_user["uid"],
        route_id=payload.route_id,
        incident_type=payload.incident_type,
        description=payload.description,
        lat=payload.lat,
        lng=payload.lng,
    )
    return IncidentResponse(**result)


@router.get("/route/{route_id}", response_model=list[IncidentResponse])
def get_incidents(route_id: str, _: dict = Depends(get_current_user)) -> list[IncidentResponse]:
    return [IncidentResponse(**i) for i in get_route_incidents(route_id)]


@router.patch("/{incident_id}/resolve", response_model=ResolveIncidentResponse)
def resolve(incident_id: str, current_user: dict = Depends(get_current_user)) -> ResolveIncidentResponse:
    result = resolve_incident(incident_id=incident_id, uid=current_user["uid"])
    return ResolveIncidentResponse(**result)
