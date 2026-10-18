from __future__ import annotations

import math

_SL_LAT_MIN, _SL_LAT_MAX = 5.9, 9.9
_SL_LNG_MIN, _SL_LNG_MAX = 79.5, 81.9


def is_valid_sri_lanka_coords(lat: float, lng: float) -> bool:
    return _SL_LAT_MIN <= lat <= _SL_LAT_MAX and _SL_LNG_MIN <= lng <= _SL_LNG_MAX


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lng / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def decode_polyline(encoded: str) -> list[tuple[float, float]]:
    """Decodes a Google Maps encoded polyline string into (lat, lng) tuples."""
    coords: list[tuple[float, float]] = []
    index = 0
    length = len(encoded)
    lat = 0
    lng = 0

    while index < length:
        result, shift = 0, 0
        while True:
            b = ord(encoded[index]) - 63
            index += 1
            result |= (b & 0x1F) << shift
            shift += 5
            if b < 0x20:
                break
        d_lat = ~(result >> 1) if result & 1 else result >> 1
        lat += d_lat

        result, shift = 0, 0
        while True:
            b = ord(encoded[index]) - 63
            index += 1
            result |= (b & 0x1F) << shift
            shift += 5
            if b < 0x20:
                break
        d_lng = ~(result >> 1) if result & 1 else result >> 1
        lng += d_lng

        coords.append((lat / 1e5, lng / 1e5))

    return coords


def _point_to_segment_distance_km(
    p_lat: float, p_lng: float,
    a_lat: float, a_lng: float,
    b_lat: float, b_lng: float,
) -> tuple[float, float, float]:
    """
    Returns (distance_km, nearest_lat, nearest_lng) from point P to segment AB.
    Uses a flat-earth approximation valid for short distances.
    """
    ax, ay = a_lng, a_lat
    bx, by = b_lng, b_lat
    px, py = p_lng, p_lat

    dx, dy = bx - ax, by - ay
    seg_len_sq = dx * dx + dy * dy

    if seg_len_sq == 0:
        return haversine_km(p_lat, p_lng, a_lat, a_lng), a_lat, a_lng

    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / seg_len_sq))
    nearest_lat = ay + t * dy
    nearest_lng = ax + t * dx
    dist = haversine_km(p_lat, p_lng, nearest_lat, nearest_lng)
    return dist, nearest_lat, nearest_lng


def snap_to_polyline(
    lat: float, lng: float, polyline_coords: list[tuple[float, float]]
) -> tuple[float, float, int]:
    """
    Snaps (lat, lng) to the nearest point on the polyline.
    Returns (snapped_lat, snapped_lng, segment_index).
    """
    if not polyline_coords:
        return lat, lng, 0

    best_dist = float("inf")
    best_lat, best_lng, best_seg = lat, lng, 0

    for i in range(len(polyline_coords) - 1):
        a_lat, a_lng = polyline_coords[i]
        b_lat, b_lng = polyline_coords[i + 1]
        dist, n_lat, n_lng = _point_to_segment_distance_km(lat, lng, a_lat, a_lng, b_lat, b_lng)
        if dist < best_dist:
            best_dist = dist
            best_lat, best_lng, best_seg = n_lat, n_lng, i

    return best_lat, best_lng, best_seg


def remaining_distance_km(
    polyline_coords: list[tuple[float, float]],
    from_lat: float,
    from_lng: float,
    segment_index: int,
) -> float:
    """
    Calculates route distance from a snapped point (at segment_index) to the end
    of the polyline.
    """
    if not polyline_coords or segment_index >= len(polyline_coords) - 1:
        return 0.0

    total = haversine_km(from_lat, from_lng, *polyline_coords[segment_index + 1])
    for i in range(segment_index + 1, len(polyline_coords) - 1):
        total += haversine_km(*polyline_coords[i], *polyline_coords[i + 1])
    return round(total, 3)


def polyline_total_km(coords: list[tuple[float, float]]) -> float:
    total = 0.0
    for i in range(len(coords) - 1):
        total += haversine_km(*coords[i], *coords[i + 1])
    return round(total, 3)
