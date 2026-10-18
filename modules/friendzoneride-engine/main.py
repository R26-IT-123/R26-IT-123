import os
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.routes import router as routes_router
from routers.bookings import router as bookings_router
from routers.payments import router as payments_router
from routers.ride_sessions import router as ride_sessions_router
from routers.feedback import router as feedback_router
from routers.notifications import router as notifications_router

app = FastAPI(title="ShareMate RouteSharing Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(routes_router)
app.include_router(bookings_router)
app.include_router(payments_router)
app.include_router(ride_sessions_router)
app.include_router(feedback_router)
app.include_router(notifications_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "routesharing"}
