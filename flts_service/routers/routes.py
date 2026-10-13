from fastapi import APIRouter, Depends

from schemas.route import BusRoute, PassengersResponse
from services.auth import get_current_user
from services.route_service import get_route, get_route_passengers, list_routes

router = APIRouter(prefix="/api/flts/routes", tags=["flts-routes"])


@router.get("", response_model=list[BusRoute])
def get_all_routes(_: dict = Depends(get_current_user)) -> list[BusRoute]:
    return [BusRoute(**r) for r in list_routes()]


@router.get("/{route_id}", response_model=BusRoute)
def get_single_route(route_id: str, _: dict = Depends(get_current_user)) -> BusRoute:
    return BusRoute(**get_route(route_id))


@router.get("/{route_id}/passengers", response_model=PassengersResponse)
def get_active_passengers(route_id: str, _: dict = Depends(get_current_user)) -> PassengersResponse:
    return PassengersResponse(**get_route_passengers(route_id))
