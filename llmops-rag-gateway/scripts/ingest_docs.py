"""
CLI script to ingest documents into the vector store.

Usage:
    # Ingest the portfolio repo docs
    python scripts/ingest_docs.py --docs-dir ./docs/corpus

    # Ingest a custom directory
    python scripts/ingest_docs.py --docs-dir /path/to/my/docs

    # Dry run (count chunks without storing)
    python scripts/ingest_docs.py --docs-dir ./docs/corpus --dry-run

Supported file types: .txt  .md  .rst  .csv

After ingestion you can query with:
    TOKEN=$(python scripts/generate_token.py)
    curl -X POST http://localhost:8000/rag/chat \\
         -H "Authorization: Bearer $TOKEN" \\
         -H "Content-Type: application/json" \\
         -d '{"question": "What does repo X do?", "top_k": 3}'
"""

import argparse
import asyncio
import logging
import os
import sys
from pathlib import Path

# Make sure the project root is on the path when running as a script
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

logging.basicConfig(level="INFO", format="%(asctime)s %(levelname)s — %(message)s")


async def main():
    parser = argparse.ArgumentParser(description="Ingest documents into the RAG vector store")
    parser.add_argument(
        "--docs-dir",
        default=os.getenv("DOCS_DIR", "./docs/corpus"),
        help="Directory containing documents to ingest",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count and show chunks without storing them",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=32,
        help="Embedding batch size (default: 32)",
    )
    args = parser.parse_args()

    docs_dir = args.docs_dir

    if args.dry_run:
        from app.rag.ingestion import load_documents
        from app.rag.chunking import chunk_document

        docs = load_documents(docs_dir)
        total_chunks = 0
        for doc in docs:
            chunks = chunk_document(doc)
            print(f"  {doc['filename']}: {len(chunks)} chunks")
            total_chunks += len(chunks)
        print(f"\nTotal chunks (dry run): {total_chunks}")
        return

    from app.rag.ingestion import ingest_directory

    total = await ingest_directory(docs_dir, batch_size=args.batch_size)
    print(f"\n✅ Ingestion complete — {total} chunks stored.")


if __name__ == "__main__":
    asyncio.run(main())
