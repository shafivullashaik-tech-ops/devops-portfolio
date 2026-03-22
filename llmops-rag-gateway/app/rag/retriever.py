"""
RAG retriever — similarity search + citation builder.

1. Embeds the incoming query
2. Searches the vector store for top-k similar chunks
3. Returns chunks with metadata (source_file, chunk_id, score, text)
   which become the citations in the API response.
"""

import logging
from typing import List, Dict, Any

from app.rag.store import get_vector_store

logger = logging.getLogger(__name__)


async def retrieve_context(
    query: str,
    top_k: int = 3,
) -> List[Dict[str, Any]]:
    """
    Retrieve top-k relevant chunks for *query*.

    Returns:
        List of dicts:
            {
              "chunk_id":    str,
              "source_file": str,
              "text":        str,
              "score":       float,   # cosine similarity [0, 1]
            }
    """
    from app.llm.client import get_embedding  # avoid circular at module load

    # Step 1 — embed the query
    try:
        embeddings = await get_embedding([query])
        query_vector = embeddings[0]
    except Exception as exc:
        logger.error("Failed to embed query: %s", exc)
        raise

    # Step 2 — vector search
    store = get_vector_store()
    try:
        results = await store.search(query_vector, top_k=top_k)
    except Exception as exc:
        logger.error("Vector search failed: %s", exc)
        raise

    logger.info(
        "retrieve_context query_snippet=%.50s top_k=%d results=%d",
        query,
        top_k,
        len(results),
    )
    return results
