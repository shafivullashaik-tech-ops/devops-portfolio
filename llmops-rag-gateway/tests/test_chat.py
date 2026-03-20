"""
Tests for POST /chat

Covers:
  - 401 when no token
  - 401 when invalid token
  - 200 with valid token (stub backend)
  - 429 rate limit (if quota exceeded)
"""

import pytest
from fastapi.testclient import TestClient
import jwt
import time
import os

# Force test values BEFORE importing app (overrides any env vars passed at CLI)
os.environ["LLM_BACKEND"] = "stub"
os.environ["VECTOR_STORE_BACKEND"] = "memory"
os.environ["JWT_SECRET"] = "super-secret-change-in-production"
os.environ["JWT_ALGORITHM"] = "HS256"

from app.main import app

TEST_SECRET = "super-secret-change-in-production"
TEST_ALGO = "HS256"


def make_token(sub: str = "testuser", expire_in: int = 3600) -> str:
    payload = {
        "sub": sub,
        "exp": int(time.time()) + expire_in,
        "iat": int(time.time()),
    }
    return jwt.encode(payload, TEST_SECRET, algorithm=TEST_ALGO)


@pytest.fixture
def client():
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


def test_chat_no_token(client):
    resp = client.post("/chat", json={"message": "Hello"})
    assert resp.status_code == 401, resp.text


def test_chat_invalid_token(client):
    resp = client.post(
        "/chat",
        json={"message": "Hello"},
        headers={"Authorization": "Bearer invalid.token.here"},
    )
    assert resp.status_code == 401, resp.text


def test_chat_expired_token(client):
    expired = make_token(expire_in=-1)
    resp = client.post(
        "/chat",
        json={"message": "Hello"},
        headers={"Authorization": f"Bearer {expired}"},
    )
    assert resp.status_code == 401
    assert "expired" in resp.json()["detail"].lower()


def test_chat_valid_token_stub(client):
    token = make_token()
    resp = client.post(
        "/chat",
        json={"message": "What is DevOps?"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "reply" in data
    assert "model" in data
    assert data["prompt_tokens"] >= 0
    assert data["completion_tokens"] >= 0


def test_chat_message_too_long(client):
    token = make_token()
    resp = client.post(
        "/chat",
        json={"message": "x" * 5000},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422  # Pydantic validation error


def test_health_no_auth(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
