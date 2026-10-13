import asyncio
import os
from contextlib import asynccontextmanager
from dotenv import load_dotenv

load_dotenv()

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware

AUTH_URL           = os.getenv("AUTH_SERVICE_URL",          "http://localhost:8001")
FLTS_URL           = os.getenv("FLTS_SERVICE_URL",           "http://localhost:8002")
ANIE_URL           = os.getenv("ANIE_SERVICE_URL",           "http://localhost:8003")
ROUTESHARING_URL   = os.getenv("ROUTESHARING_SERVICE_URL",   "http://localhost:8004")
GROC_URL           = os.getenv("GROC_SERVICE_URL",           "http://localhost:8005")
COMMUNITY_CHAT_URL = os.getenv("COMMUNITY_CHAT_SERVICE_URL", "http://localhost:8006")

ROUTE_MAP: list[tuple[str, str]] = [
    ("/api/auth",           AUTH_URL),
    ("/api/profile",        AUTH_URL),
    ("/api/flts",           FLTS_URL),
    ("/api/anie",           ANIE_URL),
    ("/api/routesharing",   ROUTESHARING_URL),
    ("/api/grocery",        GROC_URL),
    ("/api/community-chat", COMMUNITY_CHAT_URL),
]

_SERVICES = [
    ("Auth",          AUTH_URL),
    ("FLTS",          FLTS_URL),
    ("ANIE",          ANIE_URL),
    ("RouteSharing",  ROUTESHARING_URL),
    ("Grocery",       GROC_URL),
    ("CommunityChat", COMMUNITY_CHAT_URL),
]

_HOP_BY_HOP = {
    "host", "connection", "keep-alive", "transfer-encoding",
    "te", "trailers", "upgrade", "proxy-authorization", "proxy-authenticate",
}

_merged_openapi: dict | None = None


async def _fetch_service_schema(name: str, base_url: str) -> dict | None:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{base_url}/openapi.json")
            if resp.status_code == 200:
                return resp.json()
    except Exception:
        pass
    print(f"[gateway] WARNING: could not fetch schema from {name} ({base_url})")
    return None


async def _build_merged_schema() -> None:
    global _merged_openapi

    results = await asyncio.gather(
        *[_fetch_service_schema(name, url) for name, url in _SERVICES]
    )

    merged_paths: dict = {}
    merged_schemas: dict = {}
    loaded = 0

    for i, schema in enumerate(results):
        name = _SERVICES[i][0]
        if schema is None:
            continue
        loaded += 1
        for path, path_item in schema.get("paths", {}).items():
            merged_paths[path] = path_item
        for schema_name, schema_def in schema.get("components", {}).get("schemas", {}).items():
            merged_schemas[schema_name] = schema_def

    _merged_openapi = {
        "openapi": "3.1.0",
        "info": {"title": "ShareMate API Gateway", "version": "1.0.0"},
        "paths": {
            "/health": {
                "get": {
                    "tags": ["gateway"],
                    "summary": "Health",
                    "operationId": "health_health_get",
                    "responses": {
                        "200": {
                            "description": "Successful Response",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {
                                            "status":  {"type": "string"},
                                            "service": {"type": "string"},
                                        },
                                    }
                                }
                            },
                        }
                    },
                }
            },
            **merged_paths,
        },
        "components": {
            "schemas": merged_schemas,
            "securitySchemes": {
                "BearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "Firebase ID Token",
                }
            },
        },
        "security": [{"BearerAuth": []}],
    }

    print(f"[gateway] Schema built: {len(merged_paths)} paths from {loaded}/{len(_SERVICES)} services.")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await _build_merged_schema()
    yield


app = FastAPI(title="ShareMate API Gateway", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def custom_openapi() -> dict:
    if _merged_openapi is not None:
        return _merged_openapi
    return {
        "openapi": "3.1.0",
        "info": {"title": "ShareMate API Gateway", "version": "1.0.0"},
        "paths": {},
    }


app.openapi = custom_openapi  # type: ignore[method-assign]


# ---------------------------------------------------------------------------
# Gateway health
# ---------------------------------------------------------------------------

@app.get("/health", tags=["gateway"])
def health() -> dict[str, str]:
    return {"status": "ok", "service": "gateway"}


# ---------------------------------------------------------------------------
# Refresh endpoint — re-fetches schemas from all services without restarting
# ---------------------------------------------------------------------------

@app.post("/refresh-docs", tags=["gateway"])
async def refresh_docs() -> dict[str, str]:
    await _build_merged_schema()
    paths = len(_merged_openapi.get("paths", {})) if _merged_openapi else 0
    return {"status": "ok", "paths_loaded": str(paths)}


# ---------------------------------------------------------------------------
# Catch-all proxy — routes every request to the correct upstream service
# ---------------------------------------------------------------------------

@app.api_route(
    "/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"],
    include_in_schema=False,
)
async def proxy(request: Request, path: str) -> Response:
    full_path = f"/{path}"

    upstream_base: str | None = None
    for prefix, url in ROUTE_MAP:
        if full_path.startswith(prefix):
            upstream_base = url
            break

    if upstream_base is None:
        return Response(
            content='{"detail":"No upstream service for this path."}',
            status_code=404,
            media_type="application/json",
        )

    upstream_url = upstream_base + full_path
    if request.url.query:
        upstream_url += f"?{request.url.query}"

    forward_headers = {
        k: v for k, v in request.headers.items()
        if k.lower() not in _HOP_BY_HOP
    }

    body = await request.body()

    try:
        anie_path = full_path.startswith("/api/anie")
        async with httpx.AsyncClient(timeout=300.0 if anie_path else 30.0) as client:
            upstream_resp = await client.request(
                method=request.method,
                url=upstream_url,
                headers=forward_headers,
                content=body,
            )
    except httpx.ConnectError:
        return Response(
            content='{"detail":"Upstream service is unavailable."}',
            status_code=503,
            media_type="application/json",
        )
    except httpx.TimeoutException:
        return Response(
            content='{"detail":"Upstream service timed out."}',
            status_code=504,
            media_type="application/json",
        )

    response_headers = {
        k: v for k, v in upstream_resp.headers.items()
        if k.lower() not in _HOP_BY_HOP
    }

    return Response(
        content=upstream_resp.content,
        status_code=upstream_resp.status_code,
        headers=response_headers,
        media_type=upstream_resp.headers.get("content-type"),
    )
