from typing import Optional
from pydantic import BaseModel


class ReportIncidentRequest(BaseModel):
    route_id: str
    incident_type: str
    description: str
    lat: float
    lng: float


class IncidentResponse(BaseModel):
    incident_id: str
    route_id: str
    reported_by_uid: str
    incident_type: str
    description: str
    lat: float
    lng: float
    active: bool
    created_at: str
    resolved_at: Optional[str] = None


class ResolveIncidentResponse(BaseModel):
    message: str
    incident_id: str
