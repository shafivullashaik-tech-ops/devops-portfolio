"""
/chat router — direct LLM call (no RAG).
Requires valid JWT Bearer token.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.llm.client import llm_complete
from app.middleware.auth import get_current_user
from app.observability.metrics import TOKEN_USAGE

router = APIRouter()


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4096, description="User message")
    model: str = Field(default="gpt-3.5-turbo", description="LLM model name")
    max_tokens: int = Field(default=512, ge=1, le=4096)
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)


class ChatResponse(BaseModel):
    reply: str
    model: str
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


@router.post(
    "",
    response_model=ChatResponse,
    summary="Send a message to the LLM (direct, no RAG)",
    description="JWT Bearer token required in Authorization header.",
)
async def chat(
    body: ChatRequest,
    user: dict = Depends(get_current_user),
):
    """
    Direct LLM completion endpoint.
    - Auth: JWT required
    - Rate limited by RateLimiterMiddleware
    - Guardrails applied by GuardrailsMiddleware
    """
    try:
        result = await llm_complete(
            messages=[{"role": "user", "content": body.message}],
            model=body.model,
            max_tokens=body.max_tokens,
            temperature=body.temperature,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"LLM backend error: {exc}") from exc

    # Track token usage
    TOKEN_USAGE.labels(model=result["model"], type="prompt").inc(result["prompt_tokens"])
    TOKEN_USAGE.labels(model=result["model"], type="completion").inc(result["completion_tokens"])

    return ChatResponse(
        reply=result["content"],
        model=result["model"],
        prompt_tokens=result["prompt_tokens"],
        completion_tokens=result["completion_tokens"],
        total_tokens=result["total_tokens"],
    )
