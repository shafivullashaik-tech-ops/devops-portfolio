"""
Tests for POST /rag/chat

Covers:
  - Auth required
  - Returns answer + citations structure
  - Citations contain source_file + chunk_id
  - Empty store returns graceful "not enough information" message
"""

import pytest
import jwt
import time
import os

# Force test values BEFORE importing app (overrides any env vars passed at CLI)
os.environ["LLM_BACKEND"] = "stub"
os.environ["VECTOR_STORE_BACKEND"] = "memory"
os.environ["JWT_SECRET"] = "super-secret-change-in-production"
os.environ["JWT_ALGORITHM"] = "HS256"

from fastapi.testclient import TestClient
from app.main import app
from app.rag.store import get_vector_store

TEST_SECRET = "super-secret-change-in-production"


def make_token() -> str:
    payload = {"sub": "testuser", "exp": int(time.time()) + 3600}
    return jwt.encode(payload, TEST_SECRET, algorithm="HS256")


@pytest.fixture
def client():
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture(autouse=True)
def reset_store():
    """Reset the in-memory store before each test."""
    import app.rag.store as store_module
    store_module._store_instance = None
    yield
    store_module._store_instance = None


def test_rag_chat_no_auth(client):
    resp = client.post("/rag/chat", json={"question": "What is this?"})
    assert resp.status_code == 401


def test_rag_chat_empty_store_returns_graceful(client):
    """When no docs are ingested, should return a graceful 'not enough info' response."""
    token = make_token()
    resp = client.post(
        "/rag/chat",
        json={"question": "What does repo X do?"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "answer" in data
    assert "citations" in data
    assert data["citations"] == []


@pytest.mark.asyncio
async def test_rag_chat_with_ingested_doc(client):
    """Ingest a doc, then query — should return citations."""
    import asyncio
    from app.rag.store import get_vector_store
    from app.llm.client import get_embedding

    store = get_vector_store()

    # Manually ingest a test chunk with a stub embedding
    embeddings = await get_embedding(["The sre-observability-stack uses Prometheus and Grafana."])
    chunk = {
        "chunk_id": "doc_test_0",
        "source_file": "sre-README.md",
        "text": "The sre-observability-stack uses Prometheus and Grafana for monitoring.",
        "embedding": embeddings[0],
        "char_start": 0,
        "char_end": 70,
    }
    await store.upsert([chunk])

    token = make_token()
    resp = client.post(
        "/rag/chat",
        json={"question": "What monitoring tools are used?", "top_k": 1},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()

    assert "answer" in data
    assert len(data["citations"]) >= 1

    citation = data["citations"][0]
    assert citation["source_file"] == "sre-README.md"
    assert citation["chunk_id"] == "doc_test_0"
    assert "score" in citation
    assert 0.0 <= citation["score"] <= 1.0
    assert len(citation["snippet"]) > 0


def test_rag_chat_response_schema(client):
    """Verify the response schema fields are present."""
    token = make_token()
    resp = client.post(
        "/rag/chat",
        json={"question": "Tell me about the platform."},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    required_fields = ["answer", "citations", "model", "prompt_tokens", "completion_tokens", "total_tokens"]
    for field in required_fields:
        assert field in data, f"Missing field: {field}"
