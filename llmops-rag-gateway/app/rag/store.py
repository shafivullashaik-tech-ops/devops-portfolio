"""
Vector store abstraction.

Backends:
  - pgvector (PostgreSQL + pgvector extension) — production default
  - InMemoryStore                              — local dev / testing fallback

The backend is selected via the VECTOR_STORE_BACKEND env var:
  VECTOR_STORE_BACKEND=pgvector   → uses DATABASE_URL
  VECTOR_STORE_BACKEND=memory     → in-process numpy cosine similarity

pgvector schema (auto-created on first upsert):
  CREATE TABLE IF NOT EXISTS chunks (
      chunk_id    TEXT PRIMARY KEY,
      source_file TEXT NOT NULL,
      text        TEXT NOT NULL,
      embedding   vector(1536),
      char_start  INT,
      char_end    INT
  );
"""

import os
import math
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

BACKEND = os.getenv("VECTOR_STORE_BACKEND", "memory")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://rag:rag@localhost:5432/ragdb")
EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))


# ---------------------------------------------------------------------------
# Cosine similarity helper (no external deps for in-memory store)
# ---------------------------------------------------------------------------
def _cosine_similarity(a: List[float], b: List[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


# ---------------------------------------------------------------------------
# In-memory vector store (dev / CI)
# ---------------------------------------------------------------------------
class InMemoryStore:
    def __init__(self):
        self._chunks: Dict[str, Dict[str, Any]] = {}

    async def upsert(self, chunks: List[Dict[str, Any]]) -> None:
        for chunk in chunks:
            self._chunks[chunk["chunk_id"]] = chunk
        logger.debug("InMemoryStore: upserted %d chunks (total=%d)", len(chunks), len(self._chunks))

    async def search(
        self, query_vector: List[float], top_k: int = 3
    ) -> List[Dict[str, Any]]:
        if not self._chunks:
            return []

        scored = []
        for chunk in self._chunks.values():
            emb = chunk.get("embedding", [])
            if emb:
                score = _cosine_similarity(query_vector, emb)
                scored.append((score, chunk))

        scored.sort(key=lambda x: x[0], reverse=True)
        results = []
        for score, chunk in scored[:top_k]:
            results.append(
                {
                    "chunk_id": chunk["chunk_id"],
                    "source_file": chunk["source_file"],
                    "text": chunk["text"],
                    "score": score,
                }
            )
        return results

    async def count(self) -> int:
        return len(self._chunks)


# ---------------------------------------------------------------------------
# pgvector store (production)
# ---------------------------------------------------------------------------
class PgVectorStore:
    """
    Uses asyncpg + pgvector extension.
    Install: CREATE EXTENSION IF NOT EXISTS vector;
    """

    def __init__(self, dsn: str):
        self._dsn = dsn
        self._pool = None

    async def _get_pool(self):
        if self._pool is None:
            try:
                import asyncpg  # type: ignore
                self._pool = await asyncpg.create_pool(self._dsn)
                await self._ensure_table()
            except ImportError:
                raise RuntimeError("asyncpg not installed. Run: pip install asyncpg")
        return self._pool

    async def _ensure_table(self):
        pool = self._pool
        async with pool.acquire() as conn:
            await conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
            await conn.execute(
                f"""
                CREATE TABLE IF NOT EXISTS chunks (
                    chunk_id    TEXT PRIMARY KEY,
                    source_file TEXT NOT NULL,
                    text        TEXT NOT NULL,
                    embedding   vector({EMBEDDING_DIM}),
                    char_start  INT DEFAULT 0,
                    char_end    INT DEFAULT 0
                )
                """
            )

    async def upsert(self, chunks: List[Dict[str, Any]]) -> None:
        pool = await self._get_pool()
        async with pool.acquire() as conn:
            for chunk in chunks:
                emb = chunk.get("embedding", [0.0] * EMBEDDING_DIM)
                emb_str = "[" + ",".join(str(v) for v in emb) + "]"
                await conn.execute(
                    """
                    INSERT INTO chunks (chunk_id, source_file, text, embedding, char_start, char_end)
                    VALUES ($1, $2, $3, $4::vector, $5, $6)
                    ON CONFLICT (chunk_id) DO UPDATE
                        SET text=EXCLUDED.text, embedding=EXCLUDED.embedding
                    """,
                    chunk["chunk_id"],
                    chunk["source_file"],
                    chunk["text"],
                    emb_str,
                    chunk.get("char_start", 0),
                    chunk.get("char_end", 0),
                )

    async def search(
        self, query_vector: List[float], top_k: int = 3
    ) -> List[Dict[str, Any]]:
        pool = await self._get_pool()
        emb_str = "[" + ",".join(str(v) for v in query_vector) + "]"
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                f"""
                SELECT chunk_id, source_file, text,
                       1 - (embedding <=> $1::vector) AS score
                FROM chunks
                ORDER BY embedding <=> $1::vector
                LIMIT $2
                """,
                emb_str,
                top_k,
            )
        return [
            {
                "chunk_id": r["chunk_id"],
                "source_file": r["source_file"],
                "text": r["text"],
                "score": float(r["score"]),
            }
            for r in rows
        ]

    async def count(self) -> int:
        pool = await self._get_pool()
        async with pool.acquire() as conn:
            return await conn.fetchval("SELECT COUNT(*) FROM chunks")


# ---------------------------------------------------------------------------
# Singleton factory
# ---------------------------------------------------------------------------
_store_instance: Optional[Any] = None


def get_vector_store():
    global _store_instance
    if _store_instance is None:
        if BACKEND == "pgvector":
            logger.info("Using pgvector backend: %s", DATABASE_URL[:30] + "…")
            _store_instance = PgVectorStore(DATABASE_URL)
        else:
            logger.info("Using in-memory vector store (dev/test mode)")
            _store_instance = InMemoryStore()
    return _store_instance
