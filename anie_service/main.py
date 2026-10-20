import os
from contextlib import asynccontextmanager
from dotenv import load_dotenv

load_dotenv()

import certifi
os.environ.setdefault("SSL_CERT_FILE", certifi.where())
os.environ.setdefault("REQUESTS_CA_BUNDLE", certifi.where())

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.notes import router as notes_router
from routers.topics import router as topics_router
from services.scorer import load_models


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_models()
    yield


app = FastAPI(title="ShareMate ANIE Service", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(notes_router)
app.include_router(topics_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "anie"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8003, reload=False)
