import math

# Sri Lanka bounding box — reject GPS coordinates outside this
_SL_LAT_MIN, _SL_LAT_MAX = 5.9, 9.9
_SL_LNG_MIN, _SL_LNG_MAX = 79.5, 81.9


def is_valid_sri_lanka_coords(lat: float, lng: float) -> bool:
    return _SL_LAT_MIN <= lat <= _SL_LAT_MAX and _SL_LNG_MIN <= lng <= _SL_LNG_MAX


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in kilometres between two GPS points."""
    R = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = math.sin(d_lat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lng / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def centroid(coords: list[tuple[float, float]]) -> tuple[float, float] | None:
    """Average lat/lng from a list of (lat, lng) tuples. Returns None if empty."""
    if not coords:
        return None
    avg_lat = sum(c[0] for c in coords) / len(coords)
    avg_lng = sum(c[1] for c in coords) / len(coords)
    return avg_lat, avg_lng
