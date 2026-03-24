"""
Embedding + response caching.

Two caches:
  1. EmbeddingCache  — keyed by text hash, stores float vectors
  2. ResponseCache   — keyed by (messages + params) hash, stores LLM response dicts

Both use an in-memory LRU-style dict with a configurable max size.
In production, swap with Redis:
  - embeddings: Redis HSET with 24h TTL
  - responses:  Redis HSET with 5-min TTL

Environment variables:
  EMBEDDING_CACHE_SIZE  — max entries (default: 10000)
  RESPONSE_CACHE_SIZE   — max entries (default: 512)
  RESPONSE_CACHE_ENABLED — "true"/"false" (default: true)
"""

import os
import json
import hashlib
import logging
from collections import OrderedDict
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

EMBEDDING_CACHE_SIZE = int(os.getenv("EMBEDDING_CACHE_SIZE", "10000"))
RESPONSE_CACHE_SIZE = int(os.getenv("RESPONSE_CACHE_SIZE", "512"))
RESPONSE_CACHE_ENABLED = os.getenv("RESPONSE_CACHE_ENABLED", "true").lower() == "true"


class LRUCache:
    """Simple in-memory LRU cache backed by OrderedDict."""

    def __init__(self, max_size: int = 1000, name: str = "cache"):
        self._cache: OrderedDict = OrderedDict()
        self._max_size = max_size
        self._name = name
        self._hits = 0
        self._misses = 0

    def get(self, key: str) -> Optional[Any]:
        if key in self._cache:
            self._cache.move_to_end(key)
            self._hits += 1
            return self._cache[key]
        self._misses += 1
        return None

    def set(self, key: str, value: Any) -> None:
        if key in self._cache:
            self._cache.move_to_end(key)
        self._cache[key] = value
        if len(self._cache) > self._max_size:
            evicted_key, _ = self._cache.popitem(last=False)
            logger.debug("%s evicted key=%s", self._name, evicted_key[:16])

    def stats(self) -> Dict[str, int]:
        return {
            "size": len(self._cache),
            "max_size": self._max_size,
            "hits": self._hits,
            "misses": self._misses,
        }


class EmbeddingCache(LRUCache):
    """Cache embeddings by text hash."""

    def __init__(self):
        super().__init__(max_size=EMBEDDING_CACHE_SIZE, name="embedding_cache")

    def _hash(self, text: str) -> str:
        return hashlib.sha256(text.encode()).hexdigest()

    def get(self, text: str) -> Optional[List[float]]:
        return super().get(self._hash(text))

    def set(self, text: str, embedding: List[float]) -> None:
        super().set(self._hash(text), embedding)


class ResponseCache(LRUCache):
    """Cache LLM responses by (messages, model, params) hash."""

    def __init__(self):
        super().__init__(max_size=RESPONSE_CACHE_SIZE, name="response_cache")

    def make_key(
        self,
        messages: List[Dict[str, str]],
        model: str,
        max_tokens: int,
        temperature: float,
    ) -> str:
        payload = json.dumps(
            {"messages": messages, "model": model, "max_tokens": max_tokens, "temperature": temperature},
            sort_keys=True,
        )
        return hashlib.sha256(payload.encode()).hexdigest()

    def get(self, key: str) -> Optional[Dict[str, Any]]:
        if not RESPONSE_CACHE_ENABLED:
            return None
        return super().get(key)

    def set(self, key: str, value: Dict[str, Any]) -> None:
        if not RESPONSE_CACHE_ENABLED:
            return
        super().set(key, value)


# Singletons
_embedding_cache: Optional[EmbeddingCache] = None
_response_cache: Optional[ResponseCache] = None


def get_embedding_cache() -> EmbeddingCache:
    global _embedding_cache
    if _embedding_cache is None:
        _embedding_cache = EmbeddingCache()
    return _embedding_cache


def get_response_cache() -> ResponseCache:
    global _response_cache
    if _response_cache is None:
        _response_cache = ResponseCache()
    return _response_cache
