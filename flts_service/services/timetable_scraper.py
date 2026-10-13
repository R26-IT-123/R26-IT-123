"""Scrapes public bus schedules from bustimetable.lk into the
`bus_timetables` Firestore collection.

There's no public API for Sri Lankan bus timetables, so this reads the
site's Yoast sitemap to discover every route page (e.g.
"/colombo-to-kandy-luxury-bus-timetable/"), then parses each page's
departure table.

The site is hand-authored WordPress content, so table layouts aren't
fully consistent page to page (column meanings, time formats, presence of
a header row all vary). Parsing is deliberately defensive: a row is only
kept if its first cell parses as a clock time; everything else in that
row is folded into a free-text "notes" field rather than assumed to mean
anything specific (bus number vs. arrival time vs. phone number all show
up depending on the page).

Run directly (`python scrape_timetable.py`) or via the periodic APScheduler
job registered in main.py.
"""

from __future__ import annotations

import re
import time
from datetime import datetime, timezone

import requests
from bs4 import BeautifulSoup

from services.firebase import get_firestore_client

_SITEMAP_URL = "https://bustimetable.lk/post-sitemap.xml"
_COLLECTION = "bus_timetables"
_SOURCE = "bustimetable.lk"
_DOC_ID_PREFIX = "btl_"
_REQUEST_DELAY_SECONDS = 0.4
_HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; ShareMateTimetableBot/1.0)",
}

_ROUTE_URL_RE = re.compile(
    r"^https://bustimetable\.lk/[a-z0-9-]+-to-[a-z0-9-]+-bus-(?:timetable|schedule)/$"
)

# Longest/most specific first, so "Semi-Luxury" is matched before "Luxury".
_BUS_TYPE_KEYWORDS = [
    "Semi Luxury A/C",
    "Semi-Luxury A/C",
    "Super Luxury",
    "Semi Luxury",
    "Semi-Luxury",
    "Luxury A/C",
    "Highway",
    "Luxury",
    "Normal",
    "Metro",
    "A/C",
    "AC",
]

_TIME_RE = re.compile(r"^(\d{1,2})[:.](\d{2})\s*(am|pm)?$", re.IGNORECASE)


def _discover_route_urls() -> list[str]:
    resp = requests.get(_SITEMAP_URL, headers=_HEADERS, timeout=15)
    resp.raise_for_status()
    urls = re.findall(r"<loc>(.*?)</loc>", resp.text)
    return [u for u in urls if _ROUTE_URL_RE.match(u)]


def _parse_title(title: str) -> tuple[str, str, str] | None:
    """"Colombo to Kandy Luxury Bus Timetable" -> ("Colombo", "Kandy", "Luxury")."""
    title = title.strip()
    for suffix in (" Bus Timetable", " Bus Schedule"):
        if title.lower().endswith(suffix.lower()):
            title = title[: -len(suffix)]
            break
    else:
        return None

    if " to " not in title:
        return None
    origin, rest = title.split(" to ", 1)
    origin = origin.strip()
    rest = rest.strip()

    bus_type = "Normal"
    for keyword in _BUS_TYPE_KEYWORDS:
        if rest.lower().endswith(keyword.lower()):
            bus_type = keyword.replace("Semi Luxury", "Semi-Luxury")
            rest = rest[: -len(keyword)].strip()
            break

    destination = rest.strip()
    if not origin or not destination:
        return None
    return origin, destination, bus_type


def _parse_route_number(html_text: str) -> str:
    match = re.search(r"Bus Route:</strong>\s*([^<\n]+)", html_text)
    return match.group(1).strip() if match else ""


def _normalize_time(raw: str) -> str | None:
    """"3:45am" / "1.30 pm" / "14:30" -> "HH:MM" (24h). None if unparseable."""
    compact = raw.strip().lower().replace(" ", "")
    match = _TIME_RE.match(compact)
    if not match:
        return None
    hour = int(match.group(1))
    minute = match.group(2)
    meridiem = match.group(3)

    if meridiem is None:
        if hour > 23:
            return None
    elif meridiem == "am":
        hour = 0 if hour == 12 else hour
    else:  # pm
        hour = 12 if hour == 12 else hour + 12

    if hour > 23 or int(minute) > 59:
        return None
    return f"{hour:02d}:{minute}"


def _scrape_route_page(url: str) -> list[dict]:
    resp = requests.get(url, headers=_HEADERS, timeout=15)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    if soup.title is None:
        return []
    parsed = _parse_title(soup.title.get_text())
    if parsed is None:
        return []
    origin, destination, bus_type = parsed
    route_number = _parse_route_number(resp.text)

    seen: set[tuple[str, str]] = set()
    entries: list[dict] = []
    now = datetime.now(timezone.utc).isoformat()

    for table in soup.find_all("table"):
        for row in table.find_all("tr"):
            cells = [c.get_text(strip=True) for c in row.find_all("td")]
            if not cells:
                continue

            # Column order isn't consistent across pages (time-first on some,
            # a stop name first on others) — take the first cell that parses
            # as a clock time, wherever it falls in the row.
            time_idx = None
            departure_time = None
            for i, cell in enumerate(cells):
                normalized = _normalize_time(cell)
                if normalized is not None:
                    time_idx = i
                    departure_time = normalized
                    break
            if departure_time is None:
                continue

            extra = [c for j, c in enumerate(cells) if j != time_idx and c]
            notes = " · ".join(extra[:3]) if extra else None

            key = (departure_time, notes or "")
            if key in seen:
                continue
            seen.add(key)

            entries.append(
                {
                    "route_number": route_number,
                    "origin": origin,
                    "destination": destination,
                    "operator": "Private",
                    "bus_type": bus_type,
                    "departure_time": departure_time,
                    "interval_note": None,
                    "days": ["daily"],
                    "notes": notes,
                    "source": _SOURCE,
                    "source_url": url,
                    "scraped_at": now,
                }
            )
    return entries


def _slug_for(url: str) -> str:
    return url.rstrip("/").rsplit("/", 1)[-1]


def scrape_and_store(limit: int | None = None) -> dict:
    """Discovers route pages, parses them, and upserts results into
    Firestore. Only ever writes/deletes documents it owns (id prefixed
    "btl_"), so it never touches manually curated entries.
    """
    db = get_firestore_client()
    col = db.collection(_COLLECTION)

    urls = _discover_route_urls()
    if limit is not None:
        urls = urls[:limit]

    pages_ok = 0
    pages_failed = 0
    entries_written = 0

    for url in urls:
        try:
            entries = _scrape_route_page(url)
        except Exception as exc:  # noqa: BLE001 - one bad page shouldn't stop the run
            pages_failed += 1
            print(f"[timetable_scraper] failed on {url}: {exc}")
            time.sleep(_REQUEST_DELAY_SECONDS)
            continue

        if not entries:
            pages_failed += 1
            time.sleep(_REQUEST_DELAY_SECONDS)
            continue

        pages_ok += 1
        slug = _slug_for(url)
        for i, entry in enumerate(entries):
            col.document(f"{_DOC_ID_PREFIX}{slug}_{i}").set(entry)
            entries_written += 1

        time.sleep(_REQUEST_DELAY_SECONDS)

    result = {
        "pages_found": len(urls),
        "pages_ok": pages_ok,
        "pages_failed": pages_failed,
        "entries_written": entries_written,
    }
    print(f"[timetable_scraper] done: {result}")
    return result


def remove_non_scraped_entries() -> int:
    """Deletes any bus_timetables docs NOT written by this scraper (i.e.
    older hand-seeded placeholder entries), so results aren't a mix of
    illustrative and real data. Safe to call once when switching over.
    """
    db = get_firestore_client()
    col = db.collection(_COLLECTION)
    deleted = 0
    for doc in col.stream():
        if not doc.id.startswith(_DOC_ID_PREFIX):
            doc.reference.delete()
            deleted += 1
    return deleted
