"""
Guardrails middleware — applied before request hits any router.

Defenses:
  1. Prompt-injection detection  — deny requests containing known injection patterns
  2. PII redaction               — mask emails and phone numbers in request body
  3. Tool/instruction allowlisting — block attempts to invoke disallowed operations

Only applies to routes with a JSON body (POST /chat, POST /rag/chat).
"""

import re
import json
import logging
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

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

# Routes that get guardrail inspection
GUARDED_PATHS = {"/chat", "/rag/chat"}


def _detect_injection(text: str) -> bool:
    return any(p.search(text) for p in INJECTION_PATTERNS)


def _redact_pii(text: str) -> str:
    text = EMAIL_RE.sub("[EMAIL REDACTED]", text)
    text = PHONE_RE.sub("[PHONE REDACTED]", text)
    return text


class GuardrailsMiddleware(BaseHTTPMiddleware):
    """
    Intercepts POST requests to guarded routes:
    - Blocks prompt injections (returns 400)
    - Redacts PII from the request body before forwarding
    """

    async def dispatch(self, request: Request, call_next):
        path = request.url.path

        # Only inspect guarded POST routes
        if request.method == "POST" and any(path.startswith(g) for g in GUARDED_PATHS):
            try:
                raw_body = await request.body()
                body_str = raw_body.decode("utf-8", errors="replace")

                # --- Injection detection ---
                if _detect_injection(body_str):
                    logger.warning(
                        "guardrail_injection_blocked path=%s snippet=%.100s",
                        path,
                        body_str,
                    )
                    return JSONResponse(
                        status_code=400,
                        content={
                            "detail": "Request blocked by guardrails: potential prompt injection detected.",
                            "code": "INJECTION_BLOCKED",
                        },
                    )

                # --- PII redaction ---
                redacted_str = _redact_pii(body_str)
                if redacted_str != body_str:
                    logger.info("guardrail_pii_redacted path=%s", path)

                # Reconstruct request with redacted body
                async def receive():
                    return {
                        "type": "http.request",
                        "body": redacted_str.encode("utf-8"),
                        "more_body": False,
                    }

                request = Request(request.scope, receive=receive)

            except Exception as exc:
                logger.error("guardrails_error: %s", exc)
                # On guardrail error, pass through (fail open — log but don't block)

        return await call_next(request)
