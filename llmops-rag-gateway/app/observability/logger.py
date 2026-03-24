"""
Structured JSON logger.

Rules:
  - Never log prompt/response text (PII / cost risk)
  - Always log: timestamp, level, route, latency_ms, model, tokens, status
  - Output is JSON for easy ingestion by Loki / CloudWatch / Datadog
"""

import logging
import json
import sys
import os
from datetime import datetime, timezone


LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
LOG_FORMAT = os.getenv("LOG_FORMAT", "json")  # "json" or "text"


class JsonFormatter(logging.Formatter):
    """Emit log records as single-line JSON objects."""

    SAFE_KEYS = {
        "levelname", "name", "pathname", "lineno",
        "funcName", "process", "thread",
    }

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "line": record.lineno,
        }
        # Add any extra structured fields passed via logger.info(..., extra={...})
        for key, value in record.__dict__.items():
            if key not in logging.LogRecord.__dict__ and key not in self.SAFE_KEYS:
                if not key.startswith("_") and key not in ("msg", "args"):
                    # Never log fields that look like prompt/response content
                    if key.lower() not in ("prompt", "message_text", "response_text", "content"):
                        payload[key] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, default=str)


def setup_logging():
    """Configure root logger. Call once at app startup."""
    root = logging.getLogger()
    root.setLevel(LOG_LEVEL)

    # Remove default handlers
    root.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    if LOG_FORMAT == "json":
        handler.setFormatter(JsonFormatter())
    else:
        handler.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)s %(name)s — %(message)s")
        )
    root.addHandler(handler)

    # Silence noisy libs
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("asyncpg").setLevel(logging.WARNING)
