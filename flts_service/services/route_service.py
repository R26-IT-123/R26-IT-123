from fastapi import HTTPException, status
from services.firebase import get_firestore_client
from utils.geo import centroid

# SLIIT Malabe campus — origin for all routes
CAMPUS_NAME = "SLIIT Campus"
CAMPUS_LAT = 6.915309380393159
CAMPUS_LNG = 79.97271740542908

# Static route definitions — must stay in sync with the Flutter
# BusRoute.sliitRoutes list (sharemate_mobile/lib/features/flts/models/bus_route.dart).
# Each stop has: id, name, lat, lng (ordered origin → destination).
_ROUTES: dict[str, dict] = {
    "route_kaduwela": {
        "id": "route_kaduwela",
        "destination": "Kaduwela",
        "stops": [
            {"id": "kaduwela_seewali_mawatha", "name": "Seewali Mawatha", "lat": 6.920128537296916, "lng": 79.9743596707538},
            {"id": "kaduwela_kothalawela",     "name": "Kothalawela",    "lat": 6.925010842053611, "lng": 79.97875068013595},
            {"id": "kaduwela_town",            "name": "Kaduwela",      "lat": 6.936428686582979, "lng": 79.98328968423978},
        ],
    },
    "route_gampaha": {
        "id": "route_gampaha",
        "destination": "Gampaha",
        "stops": [
            {"id": "gampaha_kolonnawa", "name": "Kolonnawa", "lat": 6.9255, "lng": 79.9411},
            {"id": "gampaha_kelaniya",  "name": "Kelaniya",  "lat": 6.9625, "lng": 79.9206},
            {"id": "gampaha_town",      "name": "Gampaha",   "lat": 7.0875, "lng": 79.9994},
        ],
    },
    "route_kollupitiya": {
        "id": "route_kollupitiya",
        "destination": "Kollupitiya",
        "stops": [
            {"id": "kollu_rajagiriya", "name": "Rajagiriya",  "lat": 6.9057, "lng": 79.9090},
            {"id": "kollu_borella",    "name": "Borella",     "lat": 6.9150, "lng": 79.8800},
            {"id": "kollu_town",       "name": "Kollupitiya", "lat": 6.9028, "lng": 79.8553},
        ],
    },
    "route_panadura": {
        "id": "route_panadura",
        "destination": "Panadura",
        "stops": [
            {"id": "panadura_rajagiriya", "name": "Rajagiriya", "lat": 6.9057, "lng": 79.9090},
            {"id": "panadura_dehiwala",   "name": "Dehiwala",   "lat": 6.8510, "lng": 79.8720},
            {"id": "panadura_town",       "name": "Panadura",   "lat": 6.7120, "lng": 79.9022},
        ],
    },
    "route_jaela": {
        "id": "route_jaela",
        "destination": "Jaela",
        "stops": [
            {"id": "jaela_kelaniya", "name": "Kelaniya", "lat": 6.9625, "lng": 79.9206},
            {"id": "jaela_wattala",  "name": "Wattala",  "lat": 6.9931, "lng": 79.8917},
            {"id": "jaela_town",     "name": "Jaela",    "lat": 7.0779, "lng": 79.8911},
        ],
    },
}


_RETURN_SUFFIX = "_return"


def _build_return_trip(route: dict) -> dict:
    """Reverse-direction trip, e.g. Kaduwela → SLIIT Campus.

    Mirrors BusRoute.returnTrip on the Flutter side: reverses the stop
    order (dropping the stop that becomes the new origin) and appends a
    synthetic campus stop as the new final destination.
    """
    stops = route["stops"]
    if not stops:
        return {"id": f"{route['id']}{_RETURN_SUFFIX}", "destination": CAMPUS_NAME, "stops": []}

    reversed_intermediate = list(reversed(stops))[1:]
    campus_stop = {"id": f"{route['id']}_campus_arrival", "name": CAMPUS_NAME, "lat": CAMPUS_LAT, "lng": CAMPUS_LNG}
    return {
        "id": f"{route['id']}{_RETURN_SUFFIX}",
        "destination": CAMPUS_NAME,
        "stops": [*reversed_intermediate, campus_stop],
    }


def _resolve_route(route_id: str) -> dict | None:
    route = _ROUTES.get(route_id)
    if route:
        return route
    if route_id.endswith(_RETURN_SUFFIX):
        base = _ROUTES.get(route_id[: -len(_RETURN_SUFFIX)])
        if base:
            return _build_return_trip(base)
    return None


def _active_counts() -> dict[str, int]:
    """Count live_gps docs per route in a single Firestore query."""
    db = get_firestore_client()
    counts: dict[str, int] = {}
    for doc in db.collection("live_gps").stream():
        route_id = (doc.to_dict() or {}).get("routeId")
        if route_id:
            counts[route_id] = counts.get(route_id, 0) + 1
    return counts


def list_routes() -> list[dict]:
    counts = _active_counts()
    return [
        {**route, "active_passengers": counts.get(route_id, 0)}
        for route_id, route in _ROUTES.items()
    ]


def get_route(route_id: str) -> dict:
    route = _resolve_route(route_id)
    if not route:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Route '{route_id}' not found.")
    counts = _active_counts()
    return {**route, "active_passengers": counts.get(route_id, 0)}


def get_route_passengers(route_id: str) -> dict:
    """Read live_gps Firestore collection and return active passenger count + centroid."""
    get_route(route_id)  # raises 404 if invalid route

    db = get_firestore_client()
    docs = db.collection("live_gps").where("routeId", "==", route_id).stream()

    passengers = []
    coords = []
    for doc in docs:
        data = doc.to_dict() or {}
        passengers.append({
            "userId":      data.get("userId"),
            "displayName": data.get("displayName"),
        })
        lat = data.get("lat")
        lng = data.get("lng")
        if lat is not None and lng is not None:
            coords.append((lat, lng))

    bus_centroid = centroid(coords)
    return {
        "route_id":        route_id,
        "active_count":    len(passengers),
        "passengers":      passengers,
        "centroid_lat":    bus_centroid[0] if bus_centroid else None,
        "centroid_lng":    bus_centroid[1] if bus_centroid else None,
    }
