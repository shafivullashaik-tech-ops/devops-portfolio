# SRE Observability Stack — Operations-Grade

> **Portfolio Repo 2** | Steps 8–10 — Metrics · Logs · Traces · GameDay

A production-ready, end-to-end observability platform for Kubernetes implementing the
**Three Pillars of Observability** (Metrics → Logs → Traces) with an integrated GameDay
incident runbook and postmortem workflow.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ sample-svc   │───▶│  OTel        │───▶│   Tempo      │  │
│  │ (instrumented│    │  Collector   │    │  (Traces)    │  │
│  │  with OTel)  │    └──────────────┘    └──────────────┘  │
│  │              │                                           │
│  │  /metrics ───┼──▶  Prometheus ──▶  Grafana              │
│  │  stdout  ────┼──▶  Promtail   ──▶  Loki                 │
│  └──────────────┘                                           │
│                                                              │
│  Alertmanager ──▶ Runbooks ──▶ PagerDuty/Slack             │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Tool | Purpose |
|-------|------|---------|
| Metrics | kube-prometheus-stack | Scrape & store time-series (15d retention) |
| Dashboards | Grafana — Golden Signals | Latency / Traffic / Errors / Saturation |
| Alerts | PrometheusRule CRDs | CrashLoop · High Error Rate · High Latency |
| Runbooks | Markdown (linked from alerts) | Step-by-step mitigation guides |
| Logs | Loki + Promtail | Structured container log aggregation |
| Traces | Tempo + OpenTelemetry | Distributed request tracing |
| Correlation | trace_id in logs | One click from log → trace |
| Load Testing | k6 | GameDay failure injection |

---

## Directory Layout

```
sre-observability-stack/
├── monitoring/
│   ├── kube-prometheus-stack/
│   │   ├── values.yaml          # Production Helm values
│   │   └── install.sh           # Idempotent install script
│   ├── dashboards/
│   │   └── golden-signals.json  # Grafana dashboard (importable)
│   └── alerts/
│       └── golden-signals-rules.yaml  # PrometheusRule CRDs
├── logging/
│   └── loki-stack/
│       ├── values.yaml
│       └── install.sh
├── tracing/
│   ├── tempo/
│   │   ├── values.yaml
│   │   └── install.sh
│   └── otel-collector/
│       └── otel-collector.yaml
├── sample-service/
│   ├── src/
│   │   ├── app.js               # OTel-instrumented Express app
│   │   ├── tracer.js            # OTel SDK bootstrap
│   │   └── logger.js            # Winston + trace_id injection
│   ├── package.json
│   ├── Dockerfile
│   └── k8s/
│       ├── deployment.yaml
│       └── service.yaml
├── load-testing/
│   └── k6-scripts/
│       ├── load-test.js         # Baseline load test
│       └── failure-injection.js # Chaos / GameDay script
├── runbooks/
│   ├── crashloop.md
│   ├── high-error-rate.md
│   └── high-latency.md
└── docs/
    ├── gameday.md               # Full GameDay walkthrough
    └── postmortems/
        └── 001.md               # Postmortem — realistic format
```

---

## Quick Start

```bash
# Prerequisites: kubectl context pointing at target cluster, helm 3+

# 1. Metrics stack (Prometheus + Grafana + Alertmanager)
bash monitoring/kube-prometheus-stack/install.sh

# 2. Logging stack (Loki + Promtail)
bash logging/loki-stack/install.sh

# 3. Tracing stack (Tempo)
bash tracing/tempo/install.sh

# 4. OTel Collector
kubectl apply -f tracing/otel-collector/otel-collector.yaml

# 5. Instrumented sample service
kubectl apply -f sample-service/k8s/

# 6. Import Grafana dashboard
# Grafana → Dashboards → Import → paste golden-signals.json

# 7. GameDay load test
k6 run load-testing/k6-scripts/load-test.js
```

---

## Done When ✅

| Check | Evidence |
|-------|----------|
| Alert fires → points to runbook | `runbooks/*.md` URL in `annotations.runbook_url` |
| Grafana dashboard shows Golden Signals | `docs/screenshots/grafana-golden-signals.png` |
| One request visible in traces + logs | `docs/screenshots/tempo-trace-waterfall.png` |
| `trace_id` in logs | `docs/screenshots/loki-correlated-logs.png` |
| `docs/gameday.md` exists | ✅ |
| `docs/postmortems/001.md` exists | ✅ |
