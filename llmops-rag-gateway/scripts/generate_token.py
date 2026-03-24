"""
Generate a test JWT token for the LLM Gateway.

Usage:
    python scripts/generate_token.py
    python scripts/generate_token.py --sub myuser --ttl 86400
    python scripts/generate_token.py --sub ci-bot --ttl 3600

Output:
    Prints the Bearer token to stdout so you can copy-paste into curl / Postman.

Example curl:
    TOKEN=$(python scripts/generate_token.py)
    curl -X POST http://localhost:8000/chat \\
         -H "Authorization: Bearer $TOKEN" \\
         -H "Content-Type: application/json" \\
         -d '{"message": "What is the sre-observability-stack?"}'
"""

import argparse
import os
import time
import sys

try:
    import jwt
except ImportError:
    print("PyJWT not installed. Run: pip install PyJWT", file=sys.stderr)
    sys.exit(1)

JWT_SECRET = os.getenv("JWT_SECRET", "super-secret-change-in-production")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")


def generate(sub: str = "dev-user", ttl: int = 3600) -> str:
    now = int(time.time())
    payload = {
        "sub": sub,
        "iat": now,
        "exp": now + ttl,
        "roles": ["user"],
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def main():
    parser = argparse.ArgumentParser(description="Generate a JWT for the LLM Gateway")
    parser.add_argument("--sub", default="dev-user", help="Subject (username)")
    parser.add_argument("--ttl", type=int, default=3600, help="Token TTL in seconds")
    args = parser.parse_args()

    token = generate(sub=args.sub, ttl=args.ttl)
    print(token)


if __name__ == "__main__":
    main()
