"""
LLM client wrapper.

Supports:
  - OpenAI (default)
  - Stub mode (LLM_BACKEND=stub) — deterministic responses for CI/testing

Environment variables:
  OPENAI_API_KEY   — OpenAI API key
  LLM_BACKEND      — "openai" (default) or "stub"
  LLM_MODEL        — default model name

Caching:
  Embedding calls are cached via app.llm.cache.
"""

import os
import time
import hashlib
import logging
import asyncio
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

LLM_BACKEND = os.getenv("LLM_BACKEND", "stub")  # default to stub so tests work without API key
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
DEFAULT_MODEL = os.getenv("LLM_MODEL", "gpt-3.5-turbo")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-ada-002")
EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))


# ---------------------------------------------------------------------------
# Stub backend — deterministic, no API calls (used in CI / testing)
# ---------------------------------------------------------------------------
async def _stub_complete(
    messages: List[Dict[str, str]],
    model: str,
    max_tokens: int,
    temperature: float,
) -> Dict[str, Any]:
    """Return a deterministic stub response."""
    user_msg = next((m["content"] for m in messages if m["role"] == "user"), "")
    reply = f"[STUB] Echo: {user_msg[:80]}"
    prompt_tokens = sum(len(m["content"].split()) for m in messages)
    completion_tokens = len(reply.split())
    return {
        "content": reply,
        "model": f"stub-{model}",
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": prompt_tokens + completion_tokens,
        "latency_ms": 5,
    }


async def _stub_embedding(texts: List[str]) -> List[List[float]]:
    """Return deterministic zero-ish embeddings for testing."""
    result = []
    for text in texts:
        # Hash the text to get a reproducible but varied vector
        h = hashlib.md5(text.encode()).digest()
        base = [float(b) / 255.0 for b in h]
        # Pad/tile to EMBEDDING_DIM
        vec = (base * (EMBEDDING_DIM // len(base) + 1))[:EMBEDDING_DIM]
        result.append(vec)
    return result


# ---------------------------------------------------------------------------
# OpenAI backend
# ---------------------------------------------------------------------------
async def _openai_complete(
    messages: List[Dict[str, str]],
    model: str,
    max_tokens: int,
    temperature: float,
) -> Dict[str, Any]:
    try:
        import openai  # type: ignore
    except ImportError:
        raise RuntimeError("openai package not installed. Run: pip install openai")

    openai.api_key = OPENAI_API_KEY
    start = time.perf_counter()

    # openai >= 1.0 async client
    client = openai.AsyncOpenAI(api_key=OPENAI_API_KEY)
    response = await client.chat.completions.create(
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
    )
    latency_ms = (time.perf_counter() - start) * 1000

    choice = response.choices[0]
    usage = response.usage
    return {
        "content": choice.message.content,
        "model": response.model,
        "prompt_tokens": usage.prompt_tokens,
        "completion_tokens": usage.completion_tokens,
        "total_tokens": usage.total_tokens,
        "latency_ms": round(latency_ms, 2),
    }


async def _openai_embedding(texts: List[str]) -> List[List[float]]:
    try:
        import openai  # type: ignore
    except ImportError:
        raise RuntimeError("openai package not installed. Run: pip install openai")

    client = openai.AsyncOpenAI(api_key=OPENAI_API_KEY)
    response = await client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=texts,
    )
    return [item.embedding for item in response.data]


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------
async def llm_complete(
    messages: List[Dict[str, str]],
    model: str = DEFAULT_MODEL,
    max_tokens: int = 512,
    temperature: float = 0.7,
) -> Dict[str, Any]:
    """
    Call the configured LLM backend.
    Logs latency and token counts (no prompt text logged).
    """
    from app.llm.cache import get_response_cache  # lazy import

    cache = get_response_cache()
    cache_key = cache.make_key(messages, model, max_tokens, temperature)
    cached = cache.get(cache_key)
    if cached:
        logger.info("llm_complete cache_hit model=%s", model)
        return cached

    if LLM_BACKEND == "openai":
        result = await _openai_complete(messages, model, max_tokens, temperature)
    else:
        result = await _stub_complete(messages, model, max_tokens, temperature)

    logger.info(
        "llm_complete model=%s prompt_tokens=%d completion_tokens=%d latency_ms=%.1f",
        result["model"],
        result["prompt_tokens"],
        result["completion_tokens"],
        result.get("latency_ms", 0),
    )

    cache.set(cache_key, result)
    return result


async def get_embedding(texts: List[str]) -> List[List[float]]:
    """
    Generate embeddings for a list of texts.
    Results are cached by text hash.
    """
    from app.llm.cache import get_embedding_cache  # lazy import

    ecache = get_embedding_cache()
    results = [None] * len(texts)
    miss_indices = []
    miss_texts = []

    for i, text in enumerate(texts):
        cached = ecache.get(text)
        if cached is not None:
            results[i] = cached
        else:
            miss_indices.append(i)
            miss_texts.append(text)

    if miss_texts:
        if LLM_BACKEND == "openai":
            embeddings = await _openai_embedding(miss_texts)
        else:
            embeddings = await _stub_embedding(miss_texts)

        for idx, emb in zip(miss_indices, embeddings):
            ecache.set(texts[idx], emb)
            results[idx] = emb

    return results
