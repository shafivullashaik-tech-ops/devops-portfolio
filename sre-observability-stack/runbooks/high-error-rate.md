# Runbook: HighErrorRate / SLO Error Budget Burn

**Alert:** `HighErrorRate` · `SLOErrorBudgetBurnRateFast` · `ElevatedClientErrorRate`
**Severity:** Critical (5xx) / Warning (4xx)
**Category:** Errors
**Owner:** Backend Engineering
**Last Updated:** 2026-03-06

---

## Summary

The HTTP 5xx error rate for `sample-service` has exceeded **5%** over a 5-minute window,
or the SLO error budget is burning faster than 14.4× the allowed rate.

**SLO Target:** 99.9% success rate (0.1% error budget per month = ~43 min)

---

## Impact

| Error Rate | User Impact |
|-----------|-------------|
| 1–5% | Small fraction of users affected |
| 5–20% | Noticeable degradation, support tickets rising |
| >20% | Severe outage — escalate immediately |

---

## Diagnosis Steps

### 1. Check current error rate in Grafana

Open the [Golden Signals Dashboard](http://grafana.monitoring.svc.cluster.local/d/golden-signals/golden-signals)

Look at:
- Panel: **HTTP 5xx Error Rate** — is it spiking or sustained?
- Panel: **Request Latency** — are errors correlated with high latency?

### 2. Query Prometheus for error breakdown by route

```promql
# Error rate by route
sum(rate(http_requests_total{job="sample-service",status=~"5.."}[5m])) by (route, status)
  /
sum(rate(http_requests_total{job="sample-service"}[5m])) by (route)
```

### 3. Check application logs in Loki

```logql
# All errors in the last 15 minutes
{namespace="default", app="sample-service"} |= "error" | json | status >= 500

# Get stack traces
{namespace="default", app="sample-service"} |= "Error" | json | line_format "{{.message}} {{.stack}}"

# Filter by trace_id if you have a specific request
{namespace="default", app="sample-service"} |= "trace_id=<TRACE_ID>"
```

### 4. Correlate with traces in Tempo

```bash
# If you have a failing trace_id from logs:
# Tempo UI → Search → Trace ID → inspect waterfall for error spans
```

### 5. Check recent deployments

```bash
# Did a deploy happen recently?
kubectl rollout history deployment/sample-service -n default

# What image is currently running?
kubectl get deployment sample-service -n default -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 6. Check external dependencies

```bash
# Is a downstream service failing?
kubectl get pods -A | grep -v Running

# Check service endpoints
kubectl get endpoints -n default

# Test connectivity to a downstream dependency
kubectl exec -n default deployment/sample-service -- \
  curl -sf http://downstream-service/health || echo "DOWNSTREAM DOWN"
```

### 7. Check for configuration issues

```bash
# Recent ConfigMap changes
kubectl describe configmap sample-service-config -n default

# Check env vars
kubectl exec -n default deployment/sample-service -- env | sort
```

---

## Mitigation

### Option A — Rollback bad deployment

```bash
# Immediate rollback
kubectl rollout undo deployment/sample-service -n default

# Monitor recovery
watch kubectl rollout status deployment/sample-service -n default
```

### Option B — Feature flag / circuit breaker

```bash
# Disable a problematic feature via env var
kubectl set env deployment/sample-service -n default FEATURE_XYZ_ENABLED=false
```

### Option C — Scale out to absorb load while investigating

```bash
kubectl scale deployment sample-service -n default --replicas=6
```

### Option D — Shed traffic (last resort)

```bash
# Return 503 for a specific route via ingress annotation
kubectl annotate ingress sample-service-ingress -n default \
  nginx.ingress.kubernetes.io/server-snippet='
    location /api/heavy-endpoint {
      return 503 "Service temporarily unavailable";
    }
  '
```

---

## 4xx — Elevated Client Error Rate {#4xx}

**Alert:** `ElevatedClientErrorRate`

High 4xx rates usually indicate:
- Bad client configuration (wrong API keys, expired tokens)
- Breaking API change (route renamed/removed)
- Bot traffic / scanning

### Diagnosis

```promql
# Which routes are generating 4xx?
sum(rate(http_requests_total{job="sample-service",status=~"4.."}[5m])) by (route, status)
```

```logql
# Check 404s
{app="sample-service"} | json | status = "404"

# Check 401/403 (auth failures)
{app="sample-service"} | json | status =~ "40[13]"
```

### Mitigation

- 404: Check API documentation — was a route renamed?
- 401: Check token expiry / rotation in auth service
- 400: Check request validation — was a required field added?

---

## SLO Burn Rate {#slo-burn}

**Alert:** `SLOErrorBudgetBurnRateFast`

A 14.4× burn rate means the monthly budget will be exhausted in **5 hours**.

### Burn Rate Reference

| Burn Rate | Budget Exhausted In | Action |
|-----------|--------------------|-|
| 1× | 30 days | Normal |
| 6× | 5 days | Warning — investigate |
| 14.4× | 5 hours | **Page on-call immediately** |
| 36× | 2 hours | **Major incident** |

### Steps

1. Declare incident in Slack: `/incident declare "HighErrorRate sample-service"`
2. Follow steps 1–7 above
3. Notify stakeholders if SLO breach is imminent

---

## Traffic Drop {#traffic-drop}

**Alert:** `TrafficDrop`

RPS dropped >80% compared to 1 hour ago.

### Diagnosis

```bash
# Is ingress working?
kubectl get ingress -n default
kubectl describe ingress sample-service-ingress -n default

# Is the service selecting pods?
kubectl get endpoints sample-service -n default

# DNS resolution
kubectl exec -n default deployment/sample-service -- \
  nslookup sample-service.default.svc.cluster.local
```

---

## Escalation

| Time without resolution | Action |
|-------------------------|--------|
| 10 min | Notify #backend-oncall |
| 20 min | Page on-call engineer |
| 30 min | Declare P1 incident |

---

## Related Alerts

- `HighP99Latency`
- `PodCrashLooping`
- `SLOErrorBudgetBurnRateFast`

---

## Related Dashboards

- [Golden Signals Dashboard](http://grafana.monitoring.svc.cluster.local/d/golden-signals/golden-signals)

## Post-Incident

Template: [postmortems/001.md](../docs/postmortems/001.md)
