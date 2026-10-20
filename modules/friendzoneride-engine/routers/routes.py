from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response

from schemas.route import (
    BankAccountOut,
    DriverProfileUpdate,
    PricingSuggestion,
    RouteCreate,
    RouteOut,
    RouteUpdate,
    StandbyJoin,
)
from services.auth import get_current_user
from services.maps_service import get_route_details
from services import route_service
from services import notification_service
from utils.fare import get_rate_config

router = APIRouter(prefix="/api/routesharing", tags=["routesharing-routes"])


# ---------------------------------------------------------------------------
# Rate config
# ---------------------------------------------------------------------------

@router.get("/rates")
def get_rates(_: dict = Depends(get_current_user)) -> dict:
    return get_rate_config()


# ---------------------------------------------------------------------------
# Route publish & management
# ---------------------------------------------------------------------------

@router.post("/routes", response_model=RouteOut, status_code=201)
async def publish_route(data: RouteCreate, user: dict = Depends(get_current_user)) -> RouteOut:
    driver_id = user["uid"]

    dest_lat = data.destination_lat
    dest_lng = data.destination_lng
    if dest_lat is None or dest_lng is None:
        dest_lat, dest_lng = 6.915460326238198, 79.97233831626464

    stop_lat = data.stop_location.lat if data.stop_location else None
    stop_lng = data.stop_location.lng if data.stop_location else None

    maps = await get_route_details(
        data.start_location.lat, data.start_location.lng,
        dest_lat, dest_lng,
        waypoint_lat=stop_lat,
        waypoint_lng=stop_lng,
    )

    route = await route_service.create_route(driver_id, data, maps["distance_km"], maps["polyline"])

    # Broadcast new route to all users
    start_addr = (data.start_location.address or f"{data.start_location.lat:.4f},{data.start_location.lng:.4f}")
    all_user_ids = route_service.get_all_user_ids(excluding_uid=driver_id)
    if all_user_ids:
        notification_service.broadcast_to_users(
            all_user_ids,
            title="New ride available",
            body=f"{start_addr} → {data.destination} · {data.total_seats} seats",
            data={"route_id": route["id"], "type": "new_route",
                  "start": start_addr, "destination": data.destination},
            actor_id=driver_id,
        )

    return RouteOut(**route)


@router.get("/routes", response_model=list[RouteOut])
def search_routes(
    destination: str | None = Query(None),
    user: dict = Depends(get_current_user),
) -> list[RouteOut]:
    routes = route_service.search_all_routes(destination, exclude_driver_id=user["uid"])
    return [RouteOut(**r) for r in routes]


@router.get("/routes/{route_id}", response_model=RouteOut)
def get_route(route_id: str, _: dict = Depends(get_current_user)) -> RouteOut:
    return RouteOut(**route_service.get_route(route_id))


@router.put("/routes/{route_id}", response_model=RouteOut)
def update_route(route_id: str, data: RouteUpdate, user: dict = Depends(get_current_user)) -> RouteOut:
    return RouteOut(**route_service.update_route(route_id, user["uid"], data))


@router.delete("/routes/{route_id}", status_code=204, response_class=Response)
def deactivate_route(route_id: str, user: dict = Depends(get_current_user)) -> Response:
    route_service.deactivate_route(route_id, user["uid"])
    return Response(status_code=204)


@router.get("/routes/{route_id}/pricing", response_model=PricingSuggestion)
def get_pricing(route_id: str, _: dict = Depends(get_current_user)) -> PricingSuggestion:
    return PricingSuggestion(**route_service.get_pricing_suggestion(route_id))


# ---------------------------------------------------------------------------
# Standby queue
# ---------------------------------------------------------------------------

@router.get("/routes/{route_id}/standby")
def get_standby_queue(route_id: str, _: dict = Depends(get_current_user)) -> list[dict]:
    return route_service.get_standby_queue(route_id)


@router.post("/routes/{route_id}/standby", status_code=201)
def join_standby(route_id: str, user: dict = Depends(get_current_user)) -> dict:
    from services.firebase import get_firestore_client
    db = get_firestore_client()
    user_doc = db.collection("users").document(user["uid"]).get()
    seniority = (user_doc.to_dict() or {}).get("seniority_score", 1) if user_doc.exists else 1
    return route_service.join_standby_queue(route_id, user["uid"], seniority)


# ---------------------------------------------------------------------------
# Driver profile & routes
# ---------------------------------------------------------------------------

@router.get("/driver/profile")
def get_driver_profile(user: dict = Depends(get_current_user)) -> dict:
    return route_service.get_driver_profile(user["uid"])


@router.put("/driver/profile")
def update_driver_profile(data: DriverProfileUpdate, user: dict = Depends(get_current_user)) -> dict:
    return route_service.update_driver_profile(user["uid"], data)


@router.get("/driver/routes", response_model=list[RouteOut])
def get_my_routes(user: dict = Depends(get_current_user)) -> list[RouteOut]:
    routes = route_service.get_driver_routes(user["uid"])
    return [RouteOut(**r) for r in routes]


@router.get("/driver/{driver_id}/bank-account", response_model=BankAccountOut)
def get_driver_bank_account(driver_id: str, _: dict = Depends(get_current_user)) -> BankAccountOut:
    return BankAccountOut(**route_service.get_driver_bank_account(driver_id))


#newly checked