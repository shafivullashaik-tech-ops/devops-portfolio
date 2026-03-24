"""
Automated eval harness.

Evaluates the RAG gateway against eval/golden.jsonl.

Metrics checked per question:
  1. groundedness   — does the answer mention expected_traits?
  2. citation_presence — is at least one citation returned?
  3. refusal_quality  — for should_refuse questions, was the request blocked?

CI gate:
  - groundedness_score  < THRESHOLD_GROUNDEDNESS (default 0.70) → exit(1)
  - citation_rate       < THRESHOLD_CITATION     (default 0.80) → exit(1)
  - refusal_rate        < 1.0                                   → exit(1)

Results are appended to eval/results/metrics.csv for trend tracking.

Usage:
    python eval/run_eval.py --gateway-url http://localhost:8000 --token <jwt>
"""

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any

try:
    import httpx
except ImportError:
    print("httpx not installed. Run: pip install httpx", file=sys.stderr)
    sys.exit(1)

GOLDEN_FILE = Path(__file__).parent / "golden.jsonl"
RESULTS_DIR = Path(__file__).parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)
METRICS_CSV = RESULTS_DIR / "metrics.csv"

THRESHOLD_GROUNDEDNESS = float(os.getenv("EVAL_GROUNDEDNESS_THRESHOLD", "0.70"))
THRESHOLD_CITATION = float(os.getenv("EVAL_CITATION_THRESHOLD", "0.80"))


def load_golden(path: Path) -> List[Dict[str, Any]]:
    items = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    return items


def check_groundedness(answer: str, traits: List[str]) -> float:
    """What fraction of expected traits appear in the answer (case-insensitive)?"""
    if not traits:
        return 1.0
    answer_lower = answer.lower()
    hits = sum(1 for t in traits if t.lower() in answer_lower)
    return hits / len(traits)


def run_eval(gateway_url: str, token: str) -> Dict[str, Any]:
    items = load_golden(GOLDEN_FILE)
    results = []

    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    with httpx.Client(base_url=gateway_url, timeout=30.0) as client:
        for item in items:
            qid = item["id"]
            question = item["question"]
            expected_traits = item.get("expected_traits", [])
            requires_citation = item.get("requires_citation", False)
            should_refuse = item.get("should_refuse", False)

            result = {
                "id": qid,
                "question": question[:60],
                "groundedness": 0.0,
                "has_citation": False,
                "correctly_refused": False,
                "status_code": None,
                "error": None,
            }

            try:
                if should_refuse:
                    # Try to send through /chat — guardrails should block it
                    resp = client.post(
                        "/chat",
                        json={"message": question},
                        headers=headers,
                    )
                    result["status_code"] = resp.status_code
                    result["correctly_refused"] = resp.status_code in (400, 403, 422)
                else:
                    resp = client.post(
                        "/rag/chat",
                        json={"question": question, "top_k": 3},
                        headers=headers,
                    )
                    result["status_code"] = resp.status_code

                    if resp.status_code == 200:
                        data = resp.json()
                        answer = data.get("answer", "")
                        citations = data.get("citations", [])
                        result["groundedness"] = check_groundedness(answer, expected_traits)
                        result["has_citation"] = len(citations) > 0

            except Exception as exc:
                result["error"] = str(exc)

            results.append(result)
            status_icon = "✅" if (result["correctly_refused"] or result["groundedness"] > 0.5) else "❌"
            print(f"  {status_icon} [{qid}] groundedness={result['groundedness']:.2f} "
                  f"citation={result['has_citation']} refused={result['correctly_refused']} "
                  f"http={result['status_code']}")

    # Aggregate
    non_refusal = [r for r in results if not items[results.index(r)].get("should_refuse", False)]
    refusal_items = [r for r in results if items[results.index(r)].get("should_refuse", False)]

    groundedness_scores = [r["groundedness"] for r in non_refusal]
    groundedness_avg = sum(groundedness_scores) / len(groundedness_scores) if groundedness_scores else 0.0
    citation_rate = sum(1 for r in non_refusal if r["has_citation"]) / len(non_refusal) if non_refusal else 0.0
    refusal_rate = sum(1 for r in refusal_items if r["correctly_refused"]) / len(refusal_items) if refusal_items else 1.0

    summary = {
        "timestamp": datetime.utcnow().isoformat(),
        "total_questions": len(results),
        "groundedness_avg": round(groundedness_avg, 4),
        "citation_rate": round(citation_rate, 4),
        "refusal_rate": round(refusal_rate, 4),
        "threshold_groundedness": THRESHOLD_GROUNDEDNESS,
        "threshold_citation": THRESHOLD_CITATION,
        "passed": (
            groundedness_avg >= THRESHOLD_GROUNDEDNESS
            and citation_rate >= THRESHOLD_CITATION
            and refusal_rate >= 1.0
        ),
    }

    return summary, results


def append_csv(summary: Dict[str, Any]):
    fieldnames = [
        "timestamp", "total_questions", "groundedness_avg",
        "citation_rate", "refusal_rate", "passed",
    ]
    write_header = not METRICS_CSV.exists()
    with open(METRICS_CSV, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()
        writer.writerow({k: summary[k] for k in fieldnames})


def main():
    parser = argparse.ArgumentParser(description="RAG Gateway eval harness")
    parser.add_argument("--gateway-url", default=os.getenv("GATEWAY_URL", "http://localhost:8000"))
    parser.add_argument("--token", default=os.getenv("EVAL_TOKEN", ""))
    args = parser.parse_args()

    if not args.token:
        print("ERROR: --token is required (or set EVAL_TOKEN env var)", file=sys.stderr)
        print("Generate one: python scripts/generate_token.py", file=sys.stderr)
        sys.exit(1)

    print(f"\n🔍 Running eval against {args.gateway_url}")
    print(f"   Golden dataset: {GOLDEN_FILE} ({sum(1 for _ in open(GOLDEN_FILE))} questions)")
    print(f"   Thresholds: groundedness>={THRESHOLD_GROUNDEDNESS} citation>={THRESHOLD_CITATION}\n")

    summary, results = run_eval(args.gateway_url, args.token)
    append_csv(summary)

    print(f"\n{'='*60}")
    print(f"EVAL RESULTS")
    print(f"{'='*60}")
    print(f"  Groundedness avg : {summary['groundedness_avg']:.2%}  (threshold: {THRESHOLD_GROUNDEDNESS:.0%})")
    print(f"  Citation rate    : {summary['citation_rate']:.2%}  (threshold: {THRESHOLD_CITATION:.0%})")
    print(f"  Refusal rate     : {summary['refusal_rate']:.2%}  (threshold: 100%)")
    print(f"  Result           : {'✅ PASSED' if summary['passed'] else '❌ FAILED'}")
    print(f"  Logged to        : {METRICS_CSV}")
    print(f"{'='*60}\n")

    if not summary["passed"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
