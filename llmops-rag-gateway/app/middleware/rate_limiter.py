"""
Sliding-window rate limiter middleware with per-route quotas.

Defaults (overridable via env vars):
  /chat       → 20 requests / 60 seconds  per IP
  /rag/chat   → 10 requests / 60 seconds  per IP
  default     →  60 requests / 60 seconds  per IP

Uses an in-memory store (collections.deque).
Swap for Redis in production: replace _store with a Redis pipeline.
"""

import os
import time
import logging
from collections import defaultdict, deque
from typing import Deque, Dict, Tuple

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

logger = logging.getLogger(__name__)

# Per-route quota config: {path_prefix: (max_requests, window_seconds)}
ROUTE_QUOTAS: Dict[str, Tuple[int, int]] = {
    "/chat":     (int(os.getenv("RATE_CHAT_MAX", "20")),    int(os.getenv("RATE_CHAT_WINDOW", "60"))),
    "/rag/chat": (int(os.getenv("RATE_RAG_MAX", "10")),     int(os.getenv("RATE_RAG_WINDOW", "60"))),
}
DEFAULT_QUOTA: Tuple[int, int] = (
    int(os.getenv("RATE_DEFAULT_MAX", "60")),
    int(os.getenv("RATE_DEFAULT_WINDOW", "60")),
)

# In-memory store: key → deque of timestamps
_store: Dict[str, Deque[float]] = defaultdict(deque)


def _get_quota(path: str) -> Tuple[int, int]:
    for prefix, quota in ROUTE_QUOTAS.items():
        if path.startswith(prefix):
            return quota
    return DEFAULT_QUOTA


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


class RateLimiterMiddleware(BaseHTTPMiddleware):
    """Sliding window rate limiter — per client IP, per route."""

    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        ip = _client_ip(request)
        max_req, window = _get_quota(path)

        key = f"{ip}:{path}"
        now = time.time()
        window_start = now - window

        timestamps = _store[key]

        # Remove timestamps outside the window
        while timestamps and timestamps[0] < window_start:
            timestamps.popleft()

        if len(timestamps) >= max_req:
            retry_after = int(window - (now - timestamps[0])) + 1
            logger.warning(
                "rate_limit_exceeded ip=%s path=%s count=%d max=%d",
                ip, path, len(timestamps), max_req,
            )
            return JSONResponse(
                status_code=429,
                content={
                    "detail": f"Rate limit exceeded. Max {max_req} requests per {window}s.",
                    "retry_after_seconds": retry_after,
                },
                headers={"Retry-After": str(retry_after)},
            )

        timestamps.append(now)
        response = await call_next(request)
        remaining = max_req - len(timestamps)
        response.headers["X-RateLimit-Limit"] = str(max_req)
        response.headers["X-RateLimit-Remaining"] = str(max(0, remaining))
        response.headers["X-RateLimit-Window"] = str(window)
        return response
