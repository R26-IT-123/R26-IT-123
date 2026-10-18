import os

# Weekly commitment discount
WEEKLY_DISCOUNT_PCT: float = float(os.getenv("WEEKLY_DISCOUNT_PCT", "17"))

# Minimum number of days per booking that requires upfront payment (with
# driver approval + payment slip) instead of pay-after-ride.
UPFRONT_PAYMENT_MIN_DAYS: int = int(os.getenv("UPFRONT_PAYMENT_MIN_DAYS", "4"))

# Distance band thresholds (km)
_BAND1_MAX_KM: float = float(os.getenv("FARE_BAND1_THRESHOLD_KM", "10"))
_BAND2_MAX_KM: float = float(os.getenv("FARE_BAND2_THRESHOLD_KM", "25"))

# Per-km rate bands (LKR)
_BAND1_RATE_MIN: float = float(os.getenv("FARE_BAND1_RATE_MIN", "10"))
_BAND1_RATE_MAX: float = float(os.getenv("FARE_BAND1_RATE_MAX", "20"))
_BAND2_RATE_MIN: float = float(os.getenv("FARE_BAND2_RATE_MIN", "8"))
_BAND2_RATE_MAX: float = float(os.getenv("FARE_BAND2_RATE_MAX", "18"))
_BAND3_RATE_MIN: float = float(os.getenv("FARE_BAND3_RATE_MIN", "7"))
_BAND3_RATE_MAX: float = float(os.getenv("FARE_BAND3_RATE_MAX", "15"))

# PickMe / Uber comparison rate (LKR per km, full private hire)
_PICKME_RATE_PER_KM: float = float(os.getenv("PICKME_RATE_PER_KM", "72.5"))


def rate_band(distance_km: float) -> tuple[float, float]:
    """Returns (rate_min, rate_max) per km for the given distance."""
    if distance_km <= _BAND1_MAX_KM:
        return _BAND1_RATE_MIN, _BAND1_RATE_MAX
    elif distance_km <= _BAND2_MAX_KM:
        return _BAND2_RATE_MIN, _BAND2_RATE_MAX
    else:
        return _BAND3_RATE_MIN, _BAND3_RATE_MAX


def suggest_fare_range(distance_km: float) -> tuple[float, float]:
    """(min_fare, max_fare) per seat per trip based on platform rate bands."""
    r_min, r_max = rate_band(distance_km)
    return round(r_min * distance_km, 2), round(r_max * distance_km, 2)


def fairness_label(price: float, min_fare: float, max_fare: float) -> str:
    if price < min_fare:
        return "Below Average"
    elif price <= max_fare:
        return "Fair Price"
    elif price <= max_fare * 1.25:
        return "Above Average"
    else:
        return "High Price"


def calculate_fare(
    price_per_trip: float,
    days_count: int,
    adjusted_price_per_trip: float | None = None,
) -> dict:
    """
    Calculates total fare including weekly discount.
    Uses adjusted_price_per_trip if the passenger boards at an intermediate stop.

    Payment mode and the weekly discount are both derived from days_count
    alone, not from a client-supplied label, so they can't be spoofed by
    the request payload.
    """
    effective_price = adjusted_price_per_trip if adjusted_price_per_trip is not None else price_per_trip
    base_total = round(effective_price * days_count, 2)
    is_full_week = days_count == 7
    discount_pct = WEEKLY_DISCOUNT_PCT if is_full_week else 0.0
    discount_amount = round(base_total * discount_pct / 100, 2)
    total_fare = round(base_total - discount_amount, 2)
    return {
        "base_price": effective_price,
        "days_count": days_count,
        "discount_pct": discount_pct,
        "discount_amount": discount_amount,
        "total_fare": total_fare,
        "payment_type": "upfront" if days_count >= UPFRONT_PAYMENT_MIN_DAYS else "post-ride",
    }


def auto_price_per_trip(distance_km: float) -> float:
    """Platform-set price per trip using midpoint of the applicable rate band."""
    r_min, r_max = rate_band(distance_km)
    midpoint = (r_min + r_max) / 2
    return round(midpoint * distance_km, 2)


def pickme_estimate(distance_km: float) -> float:
    return round(distance_km * _PICKME_RATE_PER_KM, 2)


def get_rate_config() -> dict:
    """Returns the currently active rate configuration (useful for admin/debug endpoints)."""
    return {
        "band1_threshold_km": _BAND1_MAX_KM,
        "band2_threshold_km": _BAND2_MAX_KM,
        "band1_rate_min": _BAND1_RATE_MIN,
        "band1_rate_max": _BAND1_RATE_MAX,
        "band2_rate_min": _BAND2_RATE_MIN,
        "band2_rate_max": _BAND2_RATE_MAX,
        "band3_rate_min": _BAND3_RATE_MIN,
        "band3_rate_max": _BAND3_RATE_MAX,
        "pickme_rate_per_km": _PICKME_RATE_PER_KM,
        "weekly_discount_pct": WEEKLY_DISCOUNT_PCT,
    }


def adjusted_price_for_pickup(
    full_price_per_trip: float,
    total_distance_km: float,
    passenger_remaining_km: float,
) -> float:
    """Proportional per-trip price for an intermediate boarding point."""
    if total_distance_km <= 0:
        return full_price_per_trip
    ratio = min(passenger_remaining_km / total_distance_km, 1.0)
    return round(full_price_per_trip * ratio, 2)
