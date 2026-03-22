"""
Chunking strategy for document ingestion.

Strategy (documented):
  1. Fixed-size chunking  — split on character count (default 512 chars)
  2. Sentence-aware overlap — keep last N chars of previous chunk to preserve context
  3. Metadata preserved   — source_file, chunk_id (doc_<filename>_<index>)

Why 512 chars?
  - Fits inside most embedding model token limits (text-embedding-ada-002: 8191 tokens)
  - Small enough for precise retrieval, large enough for coherent context
  - Overlap of 64 chars prevents cutting mid-sentence

Chunking is intentionally simple and deterministic — no ML required.
"""

import hashlib
import os
from typing import List, Dict, Any


CHUNK_SIZE = int(os.getenv("CHUNK_SIZE", "512"))
CHUNK_OVERLAP = int(os.getenv("CHUNK_OVERLAP", "64"))


def chunk_text(
    text: str,
    source_file: str,
    chunk_size: int = CHUNK_SIZE,
    overlap: int = CHUNK_OVERLAP,
) -> List[Dict[str, Any]]:
    """
    Split *text* into overlapping fixed-size chunks.

    Returns a list of dicts:
        {
          "chunk_id":    "doc_<filename>_<index>",
          "source_file": "<filename>",
          "text":        "<chunk text>",
          "char_start":  <int>,
          "char_end":    <int>,
        }
    """
    chunks = []
    text = text.strip()
    if not text:
        return chunks

    start = 0
    index = 0
    base_name = os.path.splitext(os.path.basename(source_file))[0]

    while start < len(text):
        end = start + chunk_size
        chunk_text_content = text[start:end]

        # Try to break at a sentence boundary (. ! ?) within last 20% of chunk
        if end < len(text):
            boundary_search_start = start + int(chunk_size * 0.8)
            for sep in (".\n", ".\t", ". ", "! ", "? ", "\n\n", "\n"):
                pos = chunk_text_content.rfind(sep, int(chunk_size * 0.8))
                if pos != -1:
                    end = start + pos + len(sep)
                    chunk_text_content = text[start:end]
                    break

        chunk_id = f"doc_{base_name}_{index}"
        chunks.append(
            {
                "chunk_id": chunk_id,
                "source_file": source_file,
                "text": chunk_text_content.strip(),
                "char_start": start,
                "char_end": end,
            }
        )

        # Move start forward with overlap
        start = end - overlap
        if start >= len(text):
            break
        index += 1

    return chunks


def chunk_document(doc: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Convenience wrapper — accepts a doc dict with keys: {filename, content}.
    Returns list of chunk dicts with metadata.
    """
    return chunk_text(
        text=doc["content"],
        source_file=doc["filename"],
    )
