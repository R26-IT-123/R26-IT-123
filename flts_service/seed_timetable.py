"""One-off / re-runnable seeder for the `bus_timetables` Firestore collection.

There is no official public API for Sri Lankan bus schedules, so this
collection is curated by hand instead of pulled live from a feed. Run this
script to (re)populate a starter set of well-known intercity routes; edit the
ENTRIES list (or the Firestore console directly) to keep it current.

Usage:
    python seed_timetable.py
"""

from services.firebase import get_firestore_client

_COLLECTION = "bus_timetables"

ENTRIES = [
    {
        "route_number": "1",
        "origin": "Colombo",
        "destination": "Kandy",
        "operator": "SLTB",
        "bus_type": "Normal",
        "departure_time": "04:20",
        "interval_note": "every 15-20 min",
        "days": ["daily"],
        "notes": "Last departure ~22:00.",
    },
    {
        "route_number": "1",
        "origin": "Colombo",
        "destination": "Kandy",
        "operator": "Private",
        "bus_type": "Semi-Luxury",
        "departure_time": "05:00",
        "interval_note": "every 30 min",
        "days": ["daily"],
        "notes": "Last departure ~21:30.",
    },
    {
        "route_number": "32",
        "origin": "Colombo",
        "destination": "Galle",
        "operator": "Private",
        "bus_type": "Super Luxury",
        "departure_time": "05:00",
        "interval_note": "every 30 min via Southern Expressway",
        "days": ["daily"],
        "notes": None,
    },
    {
        "route_number": "87",
        "origin": "Colombo",
        "destination": "Jaffna",
        "operator": "Private",
        "bus_type": "Luxury A/C",
        "departure_time": "20:00",
        "interval_note": None,
        "days": ["daily"],
        "notes": "Overnight service, ~8-9 hr journey. Also 20:30 and 21:00 departures.",
    },
    {
        "route_number": "15",
        "origin": "Colombo",
        "destination": "Kurunegala",
        "operator": "SLTB",
        "bus_type": "Normal",
        "departure_time": "05:00",
        "interval_note": "every 20 min",
        "days": ["daily"],
        "notes": None,
    },
    {
        "route_number": "4",
        "origin": "Colombo",
        "destination": "Anuradhapura",
        "operator": "SLTB",
        "bus_type": "Semi-Luxury",
        "departure_time": "06:00",
        "interval_note": None,
        "days": ["daily"],
        "notes": "Additional departures at 09:00, 13:00, 17:00.",
    },
    {
        "route_number": "2",
        "origin": "Colombo",
        "destination": "Matara",
        "operator": "Private",
        "bus_type": "Super Luxury",
        "departure_time": "05:00",
        "interval_note": "every 20 min via Southern Expressway",
        "days": ["daily"],
        "notes": None,
    },
    {
        "route_number": "84",
        "origin": "Colombo",
        "destination": "Batticaloa",
        "operator": "Private",
        "bus_type": "Luxury A/C",
        "departure_time": "20:30",
        "interval_note": None,
        "days": ["daily"],
        "notes": "Overnight service, ~7-8 hr journey.",
    },
    {
        "route_number": "9",
        "origin": "Colombo",
        "destination": "Trincomalee",
        "operator": "SLTB",
        "bus_type": "Semi-Luxury",
        "departure_time": "07:00",
        "interval_note": None,
        "days": ["daily"],
        "notes": "Additional departures at 12:00, 21:00.",
    },
    {
        "route_number": "99",
        "origin": "Colombo",
        "destination": "Badulla",
        "operator": "Private",
        "bus_type": "Semi-Luxury",
        "departure_time": "06:30",
        "interval_note": None,
        "days": ["daily"],
        "notes": "Additional departures at 10:00, 14:30, 22:00.",
    },
    {
        "route_number": "16",
        "origin": "Colombo",
        "destination": "Ratnapura",
        "operator": "SLTB",
        "bus_type": "Normal",
        "departure_time": "05:00",
        "interval_note": "every 20-30 min",
        "days": ["daily"],
        "notes": None,
    },
    {
        "route_number": "240",
        "origin": "Colombo",
        "destination": "Negombo",
        "operator": "SLTB",
        "bus_type": "Normal",
        "departure_time": "05:00",
        "interval_note": "every 10-15 min",
        "days": ["daily"],
        "notes": None,
    },
    {
        "route_number": "78",
        "origin": "Kandy",
        "destination": "Nuwara Eliya",
        "operator": "Private",
        "bus_type": "Normal",
        "departure_time": "05:30",
        "interval_note": "every 30 min",
        "days": ["daily"],
        "notes": None,
    },
    {
        "route_number": "349",
        "origin": "Galle",
        "destination": "Matara",
        "operator": "SLTB",
        "bus_type": "Normal",
        "departure_time": "05:00",
        "interval_note": "every 15 min",
        "days": ["daily"],
        "notes": None,
    },
]


def seed() -> None:
    db = get_firestore_client()
    col = db.collection(_COLLECTION)

    for entry in ENTRIES:
        doc_id = "_".join(
            [
                entry["route_number"],
                entry["origin"],
                entry["destination"],
                entry["operator"],
                entry["departure_time"],
            ]
        ).lower().replace(" ", "-")
        col.document(doc_id).set(entry)
        print(f"seeded {doc_id}")

    print(f"Done — {len(ENTRIES)} entries written to '{_COLLECTION}'.")


if __name__ == "__main__":
    seed()
