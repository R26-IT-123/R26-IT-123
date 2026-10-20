import os
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.notify import router as notify_router

app = FastAPI(title="ShareMate Community Chat Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(notify_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "community-chat"}
