"""
Document ingestion pipeline.

Pipeline:
  1. Load documents from a directory (supports .txt, .md, .pdf basic text)
  2. Chunk each document using the chunking strategy
  3. Generate embeddings for each chunk (via LLM client)
  4. Store chunks + embeddings in the vector store (pgvector or in-memory fallback)

Usage (CLI):
    python scripts/ingest_docs.py --docs-dir ./docs/corpus

Usage (programmatic):
    from app.rag.ingestion import ingest_directory
    await ingest_directory("./docs/corpus")
"""

import os
import logging
import asyncio
from pathlib import Path
from typing import List, Dict, Any

from app.rag.chunking import chunk_document
from app.rag.store import get_vector_store

logger = logging.getLogger(__name__)

SUPPORTED_EXTENSIONS = {".txt", ".md", ".rst", ".csv"}


def _load_file(path: Path) -> Dict[str, Any]:
    """Read a text file and return a doc dict."""
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
        return {"filename": path.name, "filepath": str(path), "content": content}
    except Exception as exc:
        logger.warning("Failed to read %s: %s", path, exc)
        return {}


def load_documents(docs_dir: str) -> List[Dict[str, Any]]:
    """
    Walk *docs_dir* and load all supported files.
    Returns list of doc dicts: {filename, filepath, content}.
    """
    docs = []
    base = Path(docs_dir)
    if not base.exists():
        logger.error("docs_dir does not exist: %s", docs_dir)
        return docs

    for path in sorted(base.rglob("*")):
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
            doc = _load_file(path)
            if doc:
                docs.append(doc)
                logger.info("Loaded document: %s (%d chars)", path.name, len(doc["content"]))

    logger.info("Total documents loaded: %d", len(docs))
    return docs


async def ingest_directory(docs_dir: str, batch_size: int = 32) -> int:
    """
    Full ingestion pipeline:
      1. Load docs
      2. Chunk
      3. Embed (batched)
      4. Store

    Returns total number of chunks ingested.
    """
    from app.llm.client import get_embedding  # avoid circular import

    docs = load_documents(docs_dir)
    if not docs:
        logger.warning("No documents found in %s", docs_dir)
        return 0

    store = get_vector_store()
    total_chunks = 0

    for doc in docs:
        chunks = chunk_document(doc)
        if not chunks:
            continue

        logger.info("Ingesting %s → %d chunks", doc["filename"], len(chunks))

        # Embed in batches
        texts = [c["text"] for c in chunks]
        embeddings = []

        for i in range(0, len(texts), batch_size):
            batch = texts[i : i + batch_size]
            try:
                batch_embeddings = await get_embedding(batch)
                embeddings.extend(batch_embeddings)
            except Exception as exc:
                logger.error("Embedding failed for batch %d: %s", i, exc)
                # Fallback: zero vectors
                embeddings.extend([[0.0] * 1536] * len(batch))

        # Attach embeddings and store
        for chunk, embedding in zip(chunks, embeddings):
            chunk["embedding"] = embedding

        await store.upsert(chunks)
        total_chunks += len(chunks)

    logger.info("Ingestion complete. Total chunks stored: %d", total_chunks)
    return total_chunks
