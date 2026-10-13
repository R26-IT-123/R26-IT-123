import os
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv

load_dotenv()

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.routes import router as routes_router
from routers.sharing import router as sharing_router
from routers.incidents import router as incidents_router
from routers.feedback import router as feedback_router
from routers.timetable import router as timetable_router
from services.timetable_scraper import scrape_and_store

_scheduler = BackgroundScheduler(timezone="UTC")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Refreshes the bus_timetables collection from bustimetable.lk daily.
    # Runs in a background thread (BackgroundScheduler), never on the
    # request path, so a slow/broken scrape just leaves yesterday's data
    # in place instead of affecting the timetable search endpoint. First
    # run is scheduled 24h out, not immediately, so restarting this
    # service during development doesn't re-trigger a ~5 minute scrape.
    _scheduler.add_job(
        scrape_and_store,
        "interval",
        hours=24,
        id="timetable_scrape",
        next_run_time=datetime.now(timezone.utc) + timedelta(hours=24),
    )
    _scheduler.start()
    yield
    _scheduler.shutdown(wait=False)


app = FastAPI(title="ShareMate FLTS Service", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(routes_router)
app.include_router(sharing_router)
app.include_router(incidents_router)
app.include_router(feedback_router)
app.include_router(timetable_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "flts"}
