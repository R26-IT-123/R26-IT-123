import os

import httpx

from utils.geo import haversine_km

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")

_DIRECTIONS_URL = "https://maps.googleapis.com/maps/api/directions/json"


def _fallback_route_details(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> dict:
    dist = haversine_km(origin_lat, origin_lng, dest_lat, dest_lng)
    return {"distance_km": round(dist, 2), "polyline": ""}


async def get_route_details(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
    waypoint_lat: float | None = None,
    waypoint_lng: float | None = None,
) -> dict:
    """
    Calls Google Maps Directions API.
    Returns {"distance_km": float, "polyline": str}.
    Falls back to straight-line haversine when Google Maps is unavailable.
    """
    if not GOOGLE_MAPS_API_KEY:
        return _fallback_route_details(origin_lat, origin_lng, dest_lat, dest_lng)

    params = {
        "origin": f"{origin_lat},{origin_lng}",
        "destination": f"{dest_lat},{dest_lng}",
        "key": GOOGLE_MAPS_API_KEY,
    }
    if waypoint_lat is not None and waypoint_lng is not None:
        params["waypoints"] = f"{waypoint_lat},{waypoint_lng}"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(_DIRECTIONS_URL, params=params)
            resp.raise_for_status()
        data = resp.json()
    except (httpx.HTTPError, ValueError):
        return _fallback_route_details(origin_lat, origin_lng, dest_lat, dest_lng)

    if data.get("status") != "OK" or not data.get("routes"):
        return _fallback_route_details(origin_lat, origin_lng, dest_lat, dest_lng)

    leg = data["routes"][0]["legs"][0]
    distance_km = leg["distance"]["value"] / 1000.0
    polyline = data["routes"][0]["overview_polyline"]["points"]
    return {"distance_km": round(distance_km, 2), "polyline": polyline}
