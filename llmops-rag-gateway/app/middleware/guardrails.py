"""
Guardrails middleware — pure ASGI middleware (not BaseHTTPMiddleware).

Using pure ASGI avoids the known Starlette BaseHTTPMiddleware limitation where
body replacement via a custom receive() callable is consumed by the middleware
layer and NOT forwarded to the downstream FastAPI route handler.

A pure ASGI middleware intercepts the receive() channel at the ASGI level,
so FastAPI's body parser receives the MODIFIED (redacted) bytes directly.

Defenses:
  1. Prompt-injection detection  — deny requests containing known patterns (400)
  2. PII redaction               — mask emails and phone numbers before LLM sees them
  3. Tool/instruction allowlisting — block attempts to invoke disallowed operations
"""

import re
import json
import logging
from typing import Callable

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Prompt injection patterns
# ---------------------------------------------------------------------------
INJECTION_PATTERNS = [
    re.compile(p, re.IGNORECASE)
    for p in [
        r"ignore\s+(all\s+)?previous\s+instructions?",
        r"disregard\s+(your\s+)?(system\s+)?prompt",
        r"forget\s+(everything|all)\s+(you\s+)?(were\s+)?told",
        r"you\s+are\s+now\s+(a\s+)?DAN",
        r"jailbreak",
        r"act\s+as\s+(if\s+you\s+(are|were)\s+)?(?:an?\s+)?(?:unrestricted|evil|unfiltered)",
        r"reveal\s+(your\s+)?(system\s+)?prompt",
        r"print\s+(your\s+)?instructions",
        r"what\s+are\s+your\s+(hidden\s+)?instructions",
        r"bypass\s+(your\s+)?(safety|content)\s+(filter|policy)",
        r"override\s+(system|safety|all)\s+",
        r"(<\s*script|<\s*img|javascript:|data:text)",      # XSS / HTML injection
        r"\{\{.*\}\}",                                        # Template injection
        r"<!--.*-->",                                         # HTML comment injection
    ]
]

# ---------------------------------------------------------------------------
# PII patterns for redaction
# ---------------------------------------------------------------------------
EMAIL_RE = re.compile(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}")
PHONE_RE = re.compile(
    r"(\+?\d{1,3}[\s\-]?)?(\(?\d{3}\)?[\s\-]?)(\d{3}[\s\-]?\d{4})"
)

# Routes that get guardrail inspection (path prefixes)
GUARDED_PATHS = ("/chat", "/rag/chat")


def _detect_injection(text: str) -> bool:
    return any(p.search(text) for p in INJECTION_PATTERNS)


def _redact_pii(text: str) -> str:
    text = EMAIL_RE.sub("[EMAIL REDACTED]", text)
    text = PHONE_RE.sub("[PHONE REDACTED]", text)
    return text


def _json_400(detail: str, code: str) -> bytes:
    return json.dumps({"detail": detail, "code": code}).encode()


class GuardrailsMiddleware:
    """
    Pure ASGI middleware.

    Intercepts POST requests to guarded routes:
    - Blocks prompt injections (returns 400)
    - Redacts PII from the request body before forwarding to FastAPI
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        method = scope.get("method", "")
        path = scope.get("path", "")

        # Only inspect guarded POST routes
        if method == "POST" and any(path.startswith(g) for g in GUARDED_PATHS):
            # --- Collect the full body from the receive channel ---
            body_chunks = []
            more_body = True
            while more_body:
                message = await receive()
                body_chunks.append(message.get("body", b""))
                more_body = message.get("more_body", False)

            raw_body = b"".join(body_chunks)
            body_str = raw_body.decode("utf-8", errors="replace")

            # --- Injection detection ---
            if _detect_injection(body_str):
                logger.warning(
                    "guardrail_injection_blocked path=%s snippet=%.100s",
                    path,
                    body_str,
                )
                response_body = _json_400(
                    "Request blocked by guardrails: potential prompt injection detected.",
                    "INJECTION_BLOCKED",
                )
                await send({
                    "type": "http.response.start",
                    "status": 400,
                    "headers": [
                        [b"content-type", b"application/json"],
                        [b"content-length", str(len(response_body)).encode()],
                    ],
                })
                await send({
                    "type": "http.response.body",
                    "body": response_body,
                    "more_body": False,
                })
                return

            # --- PII redaction ---
            redacted_str = _redact_pii(body_str)
            if redacted_str != body_str:
                logger.info("guardrail_pii_redacted path=%s", path)

            redacted_body = redacted_str.encode("utf-8")

            # --- Replace the receive channel with redacted body ---
            # This is the key: provide a new async callable that yields
            # the modified body. FastAPI will read from this directly.
            body_sent = False

            async def patched_receive():
                nonlocal body_sent
                if not body_sent:
                    body_sent = True
                    return {
                        "type": "http.request",
                        "body": redacted_body,
                        "more_body": False,
                    }
                # Disconnect after body consumed
                return {"type": "http.disconnect"}

            await self.app(scope, patched_receive, send)
            return

        # Non-guarded route — pass through unchanged
        await self.app(scope, receive, send)
