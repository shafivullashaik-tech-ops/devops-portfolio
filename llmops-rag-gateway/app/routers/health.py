"""
Health check router — /health
No auth required (used by load balancers and k8s probes).
"""

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()


class HealthResponse(BaseModel):
    status: str
    version: str


@router.get("/health", response_model=HealthResponse, summary="Liveness probe")
async def health():
    """Returns 200 OK when the service is up."""
    return HealthResponse(status="ok", version="1.0.0")
