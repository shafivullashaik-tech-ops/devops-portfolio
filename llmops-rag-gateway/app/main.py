"""
LLM Gateway API — single entrypoint for all LLM + RAG traffic.
Routes: /health, /metrics, /chat, /rag/chat
Auth:   JWT Bearer token
"""

import time
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import make_asgi_app

from app.routers import chat, rag, health
from app.middleware.auth import JWTAuthMiddleware
from app.middleware.rate_limiter import RateLimiterMiddleware
from app.middleware.guardrails import GuardrailsMiddleware
from app.observability.metrics import REQUEST_COUNT, REQUEST_LATENCY, setup_metrics

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App factory
# ---------------------------------------------------------------------------
app = FastAPI(
    title="LLM Ops RAG Gateway",
    version="1.0.0",
    description=(
        "Production-grade LLM Gateway with RAG pipeline, "
        "guardrails, rate limiting, and full observability"
    ),
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
)

# Middleware stack — applied in reverse order (last added = outermost)
app.add_middleware(GuardrailsMiddleware)
app.add_middleware(RateLimiterMiddleware)
app.add_middleware(JWTAuthMiddleware)


# ---------------------------------------------------------------------------
# Prometheus metrics endpoint (public — no auth)
# ---------------------------------------------------------------------------
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)


# ---------------------------------------------------------------------------
# Per-request telemetry hook
# ---------------------------------------------------------------------------
@app.middleware("http")
async def telemetry_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    latency = time.perf_counter() - start
    route = request.url.path
    method = request.method
    status = response.status_code

    REQUEST_COUNT.labels(method=method, route=route, status=status).inc()
    REQUEST_LATENCY.labels(route=route).observe(latency)

    logger.info(
        "http_request method=%s route=%s status=%s latency_ms=%.2f",
        method,
        route,
        status,
        latency * 1000,
    )
    return response


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------
app.include_router(health.router, tags=["health"])
app.include_router(chat.router, prefix="/chat", tags=["chat"])
app.include_router(rag.router, prefix="/rag", tags=["rag"])

setup_metrics()
