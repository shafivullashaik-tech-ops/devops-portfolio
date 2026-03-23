"""
Prometheus metrics definitions.

Metrics exported (visible at /metrics):
  llm_request_total          — Counter  — {method, route, status}
  llm_request_latency_seconds — Histogram — {route}         — p50/p95/p99
  llm_token_usage_total       — Counter  — {model, type}    — prompt / completion
  llm_cache_hits_total        — Counter  — {cache_type}     — embedding / response
  llm_guardrail_blocks_total  — Counter  — {block_type}     — injection / pii

All metrics use the "llm_" prefix for easy Grafana filtering.
"""

import os
from prometheus_client import Counter, Histogram, Gauge, CollectorRegistry, REGISTRY

# ---------------------------------------------------------------------------
# Request / latency
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "llm_request_total",
    "Total HTTP requests",
    ["method", "route", "status"],
)

REQUEST_LATENCY = Histogram(
    "llm_request_latency_seconds",
    "HTTP request latency in seconds",
    ["route"],
    buckets=[0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0],
)

# ---------------------------------------------------------------------------
# Token usage (cost tracking)
# ---------------------------------------------------------------------------
TOKEN_USAGE = Counter(
    "llm_token_usage_total",
    "Total LLM tokens used",
    ["model", "type"],  # type: prompt | completion
)

# ---------------------------------------------------------------------------
# Cache efficiency
# ---------------------------------------------------------------------------
CACHE_HITS = Counter(
    "llm_cache_hits_total",
    "Cache hits",
    ["cache_type"],  # embedding | response
)

CACHE_MISSES = Counter(
    "llm_cache_misses_total",
    "Cache misses",
    ["cache_type"],
)

# ---------------------------------------------------------------------------
# Guardrails
# ---------------------------------------------------------------------------
GUARDRAIL_BLOCKS = Counter(
    "llm_guardrail_blocks_total",
    "Requests blocked by guardrails",
    ["block_type"],  # injection | pii_redacted
)

# ---------------------------------------------------------------------------
# Ingestion
# ---------------------------------------------------------------------------
CHUNKS_INGESTED = Counter(
    "llm_chunks_ingested_total",
    "Total document chunks ingested into vector store",
)

VECTOR_STORE_SIZE = Gauge(
    "llm_vector_store_chunks",
    "Current number of chunks in the vector store",
)


def setup_metrics():
    """Called once at startup — initialise label combinations to avoid sparse series."""
    REQUEST_COUNT.labels(method="GET", route="/health", status=200)
    REQUEST_COUNT.labels(method="POST", route="/chat", status=200)
    REQUEST_COUNT.labels(method="POST", route="/rag/chat", status=200)
    TOKEN_USAGE.labels(model="gpt-3.5-turbo", type="prompt")
    TOKEN_USAGE.labels(model="gpt-3.5-turbo", type="completion")
    CACHE_HITS.labels(cache_type="embedding")
    CACHE_HITS.labels(cache_type="response")
    CACHE_MISSES.labels(cache_type="embedding")
    CACHE_MISSES.labels(cache_type="response")
    GUARDRAIL_BLOCKS.labels(block_type="injection")
    GUARDRAIL_BLOCKS.labels(block_type="pii_redacted")
