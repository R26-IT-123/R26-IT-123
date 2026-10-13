"""Run a one-off scrape of bustimetable.lk into the `bus_timetables`
Firestore collection. Same logic the background scheduler in main.py runs
every 24h — use this to trigger a refresh on demand.

Usage:
    python scrape_timetable.py              # scrape every route page found
    python scrape_timetable.py --limit 20    # scrape only the first 20 (testing)
    python scrape_timetable.py --clean       # also delete old hand-seeded entries
"""

import argparse

from services.timetable_scraper import remove_non_scraped_entries, scrape_and_store

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()

    scrape_and_store(limit=args.limit)

    if args.clean:
        removed = remove_non_scraped_entries()
        print(f"Removed {removed} non-scraped entries.")
