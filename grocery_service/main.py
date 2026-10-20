import os
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.announcements import router as announcements_router
from routers.requests import router as requests_router
from routers.chats import router as chats_router
from routers.item_requests import router as item_requests_router
from routers.feedback import router as feedback_router
from routers.notifications import router as notifications_router

app = FastAPI(title="ShareMate Grocery Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(announcements_router)
app.include_router(requests_router)
app.include_router(chats_router)
app.include_router(item_requests_router)
app.include_router(feedback_router)
app.include_router(notifications_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "grocery"}
