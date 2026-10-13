from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class PaymentSlipSubmit(BaseModel):
    slip_image_url: str  # Firebase Storage URL after upload from mobile


class PaymentSlipOut(BaseModel):
    id: str
    booking_id: str
    passenger_id: str
    slip_image_url: str
    submitted_at: datetime | None = None
    review_status: str  # pending / approved / rejected
    reviewed_by_driver_at: datetime | None = None
    rejection_reason: str | None = None


class SlipReject(BaseModel):
    rejection_reason: str  # "Wrong amount" | "Image is unclear" | "Cannot verify" | "Other"


class TripPaymentMark(BaseModel):
    booking_id: str
    trip_date: str  # "YYYY-MM-DD"
    amount: float
    payment_method: str = "cash"  # "cash" | "mobile"


class TripPaymentOut(BaseModel):
    id: str
    booking_id: str
    ride_session_id: str
    trip_date: str
    amount: float
    payment_method: str
    paid_at: datetime | None = None
    marked_by_driver: str
