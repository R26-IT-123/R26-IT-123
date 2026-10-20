from typing import Optional
from pydantic import BaseModel


class TimetableEntryResponse(BaseModel):
    id: str
    route_number: str
    origin: str
    destination: str
    operator: str        # "SLTB" | "Private"
    bus_type: str         # "Normal" | "Semi-Luxury" | "Luxury A/C" | "Super Luxury"
    departure_time: str   # "HH:MM" 24h, or a frequency note (see interval_note)
    interval_note: Optional[str] = None  # e.g. "every 15-20 min" for frequent routes
    days: list[str]       # ["daily"] or ["mon", "tue", ...]
    notes: Optional[str] = None
    source: Optional[str] = None      # e.g. "bustimetable.lk"
    source_url: Optional[str] = None
