from services.firebase import get_firestore_client

_COLLECTION = "bus_timetables"


def list_timetables(
    origin: str | None = None,
    destination: str | None = None,
    route_number: str | None = None,
) -> list[dict]:
    db = get_firestore_client()
    docs = db.collection(_COLLECTION).stream()

    entries: list[dict] = []
    for doc in docs:
        data = doc.to_dict() or {}
        data["id"] = doc.id
        entries.append(data)

    origin_q = (origin or "").strip().lower()
    destination_q = (destination or "").strip().lower()
    route_number_q = (route_number or "").strip().lower()

    def matches(entry: dict) -> bool:
        if origin_q and origin_q not in (entry.get("origin") or "").lower():
            return False
        if destination_q and destination_q not in (entry.get("destination") or "").lower():
            return False
        if route_number_q and route_number_q not in (entry.get("route_number") or "").lower():
            return False
        return True

    filtered = [e for e in entries if matches(e)]
    filtered.sort(key=lambda e: (e.get("origin") or "", e.get("departure_time") or ""))
    return filtered
