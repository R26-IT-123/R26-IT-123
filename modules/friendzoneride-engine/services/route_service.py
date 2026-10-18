from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from google.cloud.firestore_v1 import FieldFilter

from schemas.route import DriverProfileUpdate, RouteCreate, RouteUpdate
from services.firebase import get_firestore_client
from utils.fare import auto_price_per_trip, suggest_fare_range
from utils.geo import is_valid_sri_lanka_coords

_ROUTES_COL = "routesharing_routes"
_ROUTE_PRICING_COL = "routesharing_route_pricing"
_USERS_COL = "users"
_STANDBY_COL = "routesharing_standby_queue"

ROUTE_MATCH_RADIUS_KM: float = float(os.getenv("ROUTE_MATCH_RADIUS_KM", "1.0"))


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

async def create_route(driver_id: str, data: RouteCreate, distance_km: float, polyline: str) -> dict:
    db = get_firestore_client()

    driver_doc = db.collection(_USERS_COL).document(driver_id).get()
    driver_year = (driver_doc.to_dict() or {}).get("year") if driver_doc.exists else None

    end_date = data.start_date + timedelta(days=7)
    price_per_trip = auto_price_per_trip(distance_km)
    price_per_km = round(price_per_trip / distance_km, 2) if distance_km > 0 else None
    min_fare, max_fare = suggest_fare_range(distance_km)

    now = datetime.now(timezone.utc)
    route_doc = {
        "driver_id": driver_id,
        "start_location": data.start_location.model_dump(),
        "destination": data.destination,
        "destination_lat": data.destination_lat,
        "destination_lng": data.destination_lng,
        "stop_location": data.stop_location.model_dump() if data.stop_location else None,
        "route_polyline": polyline,
        "total_distance_km": distance_km,
        "start_date": data.start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "departure_time": data.departure_time,
        "total_seats": data.total_seats,
        "seats_available": data.total_seats,
        "price_per_trip": price_per_trip,
        "price_per_km": price_per_km,
        "vehicle_type": data.vehicle_type or "car",
        "driver_year": driver_year,
        "waypoints": [w.model_dump() for w in data.waypoints],
        "status": "active",
        "has_return_trip": data.has_return_trip,
        "return_departure_time": data.return_departure_time,
        "parked_location": data.parked_location.model_dump() if data.parked_location else None,
        "created_at": now,
    }

    _, ref = db.collection(_ROUTES_COL).add(route_doc)
    route_doc["id"] = ref.id

    # Store pricing details separately
    db.collection(_ROUTE_PRICING_COL).document(ref.id).set({
        "route_id": ref.id,
        "distance_km": distance_km,
        "suggested_min_fare": min_fare,
        "suggested_max_fare": max_fare,
        "platform_set_fare": price_per_trip,
        "price_per_km": price_per_km,
        "created_at": now,
    })

    return route_doc


def get_route(route_id: str) -> dict:
    db = get_firestore_client()
    doc = db.collection(_ROUTES_COL).document(route_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")
    data = doc.to_dict() or {}
    data["id"] = doc.id
    return data


def _is_expired(data: dict) -> bool:
    end = data.get("end_date")
    if not end:
        return False
    try:
        from datetime import date as _date
        return _date.fromisoformat(str(end)[:10]) < _date.today()
    except (ValueError, TypeError):
        return False


def search_all_routes(destination: str | None, exclude_driver_id: str | None = None) -> list[dict]:
    db = get_firestore_client()
    query = db.collection(_ROUTES_COL).where(filter=FieldFilter("status", "==", "active"))
    results = []
    for doc in query.stream():
        data = doc.to_dict() or {}
        if _is_expired(data):
            continue
        if destination:
            q = destination.lower()
            dest_match = q in (data.get("destination", "") or "").lower()
            start_addr = (data.get("start_location") or {}).get("address", "") or ""
            start_match = q in start_addr.lower()
            if not dest_match and not start_match:
                continue
        if exclude_driver_id and data.get("driver_id") == exclude_driver_id:
            continue
        data["id"] = doc.id
        results.append(data)

    def _ts(r: dict) -> float:
        v = r.get("created_at")
        try:
            return v.timestamp() if v is not None else 0.0
        except Exception:
            return 0.0

    results.sort(key=_ts, reverse=True)
    return results


def get_driver_routes(driver_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = db.collection(_ROUTES_COL).where(filter=FieldFilter("driver_id", "==", driver_id)).stream()
    routes = []
    for doc in docs:
        data = doc.to_dict() or {}
        if data.get("status") == "inactive" or _is_expired(data):
            continue
        data["id"] = doc.id
        routes.append(data)
    return routes


def update_route(route_id: str, driver_id: str, data: RouteUpdate) -> dict:
    db = get_firestore_client()
    doc_ref = db.collection(_ROUTES_COL).document(route_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")
    existing = doc.to_dict() or {}
    if existing.get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your route.")

    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    if not updates:
        existing["id"] = route_id
        return existing

    doc_ref.update(updates)
    existing.update(updates)
    existing["id"] = route_id
    return existing


def deactivate_route(route_id: str, driver_id: str) -> None:
    db = get_firestore_client()
    doc_ref = db.collection(_ROUTES_COL).document(route_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")
    if (doc.to_dict() or {}).get("driver_id") != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your route.")
    doc_ref.update({"status": "inactive"})


def get_pricing_suggestion(route_id: str) -> dict:
    db = get_firestore_client()
    doc = db.collection(_ROUTE_PRICING_COL).document(route_id).get()
    if not doc.exists:
        route = get_route(route_id)
        distance_km = route.get("total_distance_km") or 0
        min_fare, max_fare = suggest_fare_range(distance_km)
        r_min, r_max = (10, 20) if distance_km <= 10 else (8, 18) if distance_km <= 25 else (7, 15)
        return {
            "distance_km": distance_km,
            "suggested_min_fare": min_fare,
            "suggested_max_fare": max_fare,
            "rate_per_km_min": r_min,
            "rate_per_km_max": r_max,
            "driver_set_fare": route.get("price_per_trip"),
            "price_per_km": route.get("price_per_km"),
            "fairness_label": route.get("fairness_label"),
            "pickme_equivalent": round(distance_km * 72.5, 2),
        }
    data = doc.to_dict() or {}
    distance_km = data.get("distance_km", 0)
    r_min, r_max = (10, 20) if distance_km <= 10 else (8, 18) if distance_km <= 25 else (7, 15)
    data["rate_per_km_min"] = r_min
    data["rate_per_km_max"] = r_max
    data["pickme_equivalent"] = round(distance_km * 72.5, 2)
    return data


# ---------------------------------------------------------------------------
# Driver profile
# ---------------------------------------------------------------------------

def get_driver_profile(driver_id: str) -> dict:
    db = get_firestore_client()
    data = _get_user_profile(db, driver_id)
    return {
        "is_driver": data.get("is_driver", False),
        "home_location": data.get("home_location"),
        "regular_destination": data.get("regular_destination"),
        "usual_departure_time": data.get("usual_departure_time"),
        "vehicle_type": data.get("vehicle_type"),
        "vehicle_seats": data.get("vehicle_seats"),
        "seniority_score": data.get("seniority_score"),
        "preferred_route_id": data.get("preferred_route_id"),
        "bank_account_holder": data.get("bank_account_holder"),
        "bank_name": data.get("bank_name"),
        "bank_account_number": data.get("bank_account_number"),
        "bank_branch": data.get("bank_branch"),
    }


def get_driver_bank_account(driver_id: str) -> dict:
    db = get_firestore_client()
    data = _get_user_profile(db, driver_id)
    return {
        "driver_id": driver_id,
        "bank_account_holder": data.get("bank_account_holder"),
        "bank_name": data.get("bank_name"),
        "bank_account_number": data.get("bank_account_number"),
        "bank_branch": data.get("bank_branch"),
    }


def update_driver_profile(driver_id: str, data: DriverProfileUpdate) -> dict:
    db = get_firestore_client()
    updates = {}
    if data.is_driver is not None:
        updates["is_driver"] = data.is_driver
    if data.home_location is not None:
        updates["home_location"] = data.home_location.model_dump()
    if data.regular_destination is not None:
        updates["regular_destination"] = data.regular_destination
    if data.usual_departure_time is not None:
        updates["usual_departure_time"] = data.usual_departure_time
    if data.vehicle_type is not None:
        updates["vehicle_type"] = data.vehicle_type
    if data.vehicle_seats is not None:
        updates["vehicle_seats"] = data.vehicle_seats
    if data.bank_account_holder is not None:
        updates["bank_account_holder"] = data.bank_account_holder
    if data.bank_name is not None:
        updates["bank_name"] = data.bank_name
    if data.bank_account_number is not None:
        updates["bank_account_number"] = data.bank_account_number
    if data.bank_branch is not None:
        updates["bank_branch"] = data.bank_branch

    if updates:
        db.collection(_USERS_COL).document(driver_id).set(updates, merge=True)
    return get_driver_profile(driver_id)


# ---------------------------------------------------------------------------
# Standby queue
# ---------------------------------------------------------------------------

def join_standby_queue(route_id: str, passenger_id: str, seniority_score: int) -> dict:
    db = get_firestore_client()
    get_route(route_id)  # validates route exists
    doc_id = f"{route_id}_{passenger_id}"
    entry = {
        "route_id": route_id,
        "passenger_id": passenger_id,
        "seniority_score": seniority_score,
        "requested_at": datetime.now(timezone.utc),
    }
    db.collection(_STANDBY_COL).document(doc_id).set(entry)
    entry["id"] = doc_id
    return entry


def get_standby_queue(route_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = (
        db.collection(_STANDBY_COL)
        .where(filter=FieldFilter("route_id", "==", route_id))
        .order_by("seniority_score", direction="DESCENDING")
        .stream()
    )
    queue = []
    for doc in docs:
        data = doc.to_dict() or {}
        data["id"] = doc.id
        queue.append(data)
    return queue


def get_all_user_ids(excluding_uid: str) -> list[str]:
    db = get_firestore_client()
    return [doc.id for doc in db.collection(_USERS_COL).stream() if doc.id != excluding_uid]


def _get_user_profile(db, user_id: str) -> dict:
    doc = db.collection(_USERS_COL).document(user_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    data = doc.to_dict() or {}
    data.setdefault("uid", doc.id)
    return data
