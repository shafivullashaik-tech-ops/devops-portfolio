# Runbook: HighP99Latency / ElevatedP50Latency

**Alert:** `HighP99Latency` · `ElevatedP50Latency` · `HighCPUSaturation` · `HighMemorySaturation`
**Severity:** Critical (P99 > 1s) / Warning (P50 > 500ms)
**Category:** Latency · Saturation
**Owner:** Backend Engineering / Platform Engineering
**Last Updated:** 2026-03-06

---

## Summary

Request latency for `sample-service` has breached the SLO threshold:
- **P99 > 1 second** → Critical — affects tail users, SLO breach imminent
- **P50 > 500ms** → Warning — majority of users affected

**SLO Targets:**
- P99 latency ≤ 1s
- P50 latency ≤ 200ms

---

## Impact

| Percentile | Threshold Breached | User Impact |
|------------|-------------------|-------------|
| P50 > 500ms | Warning | Most requests slow |
| P95 > 800ms | Warning | Power users impacted |
| P99 > 1s | Critical | Tail users see timeouts |
| P99 > 3s | Severe | Client-side timeouts; cascading failures |

---

## Diagnosis Steps

### 1. Check latency in Grafana

Open [Golden Signals Dashboard](http://grafana.monitoring.svc.cluster.local/d/golden-signals/golden-signals)

- Panel: **Request Latency Percentiles** — when did latency start climbing?
- Correlate with: **Request Rate** and **Error Rate**

### 2. Identify the slowest routes

```promql
# P99 by route
histogram_quantile(
  0.99,
  sum(rate(http_request_duration_seconds_bucket{job="sample-service"}[5m])) by (le, route)
)
```

### 3. Check saturation (CPU / Memory)

```bash
# Live resource usage
kubectl top pods -n default --sort-by=cpu
kubectl top pods -n default --sort-by=memory

# Is HPA triggered?
kubectl get hpa -n default
kubectl describe hpa sample-service -n default
```

```promql
# CPU saturation
sum(rate(container_cpu_usage_seconds_total{namespace="default",container="sample-service"}[5m])) by (pod)
  /
sum(kube_pod_container_resource_limits{namespace="default",container="sample-service",resource="cpu"}) by (pod)
```

### 4. Check traces in Tempo (find the slow span)

```bash
# Tempo UI → Service graph → select sample-service
# Filter by: duration > 1s
# Look for:
#   - Which span is slow?
#   - Is it the app itself or a downstream call?
#   - Are there N+1 DB queries?
```

### 5. Check for slow external dependencies

```bash
# Check downstream service health
kubectl get pods -A | grep -v Running

# If DB is involved — check connection pool
kubectl exec -n default deployment/sample-service -- \
  node -e "const h=require('http'); h.get('http://localhost:3000/health', r => console.log(r.statusCode))"
```

### 6. Check for garbage collection / event loop lag

```bash
# Node.js specific — check event loop lag metric
# Query in Prometheus:
# nodejs_eventloop_lag_seconds{job="sample-service"}
```

```promql
# Event loop lag
nodejs_eventloop_lag_seconds{job="sample-service"} > 0.1
```

### 7. Check logs for slow query warnings

```logql
# Loki: slow operations
{app="sample-service"} | json | duration > 500
{app="sample-service"} |= "slow" | json
{app="sample-service"} |= "timeout" | json
```

---

## Mitigation

### Option A — Scale out (reduce per-pod load)

```bash
# Manual scale-out
kubectl scale deployment sample-service -n default --replicas=6

# Or trigger HPA immediately (lower threshold)
kubectl patch hpa sample-service -n default \
  --type=merge \
  -p='{"spec":{"minReplicas":4}}'
```

### Option B — Increase resource limits (if CPU-throttled)

```bash
# Check if CPU is being throttled
kubectl exec -n default <pod> -- cat /sys/fs/cgroup/cpu/cpu.stat | grep throttled

# If throttled, increase CPU limit
kubectl patch deployment sample-service -n default --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"1000m"}]'
```

### Option C — Enable/tune connection pooling

```bash
# Set DB pool size via env var
kubectl set env deployment/sample-service -n default \
  DB_POOL_MIN=5 DB_POOL_MAX=20
```

### Option D — Rollback (if caused by recent deploy)

```bash
kubectl rollout undo deployment/sample-service -n default
kubectl rollout status deployment/sample-service -n default
```

### Option E — Add circuit breaker / timeout

If latency is caused by a slow downstream dependency, add a timeout:

```bash
kubectl set env deployment/sample-service -n default \
  DOWNSTREAM_TIMEOUT_MS=500 \
  CIRCUIT_BREAKER_ENABLED=true
```

---

## P50 Latency {#p50}

**Alert:** `ElevatedP50Latency`

Median latency > 500ms affects the _majority_ of users.

Primary causes:
1. **CPU throttling** — limits too low for current traffic
2. **Synchronous I/O** — blocking calls in the event loop
3. **Large payloads** — response bodies too big (enable compression)
4. **Cold start** — new pods handling traffic before warm-up

Quick check:

```bash
# Is compression enabled?
kubectl exec -n default deployment/sample-service -- \
  curl -sI -H "Accept-Encoding: gzip" http://localhost:3000/api/items | grep -i content-encoding
```

---

## Saturation {#saturation}

**Alerts:** `HighCPUSaturation` · `HighMemorySaturation`

### CPU

```bash
# Which container is throttled?
kubectl top pods -n default
kubectl describe node $(kubectl get pod <pod> -n default -o jsonpath='{.spec.nodeName}')

# Immediate mitigation: increase replicas
kubectl scale deployment sample-service -n default --replicas=4
```

### Memory

```bash
# Check working set vs limit
kubectl top pods -n default --sort-by=memory

# Check for leaks using heapdump (Node.js)
kubectl exec -n default <pod> -- node --heapsnapshot-signal=SIGUSR2 &
kubectl exec -n default <pod> -- kill -USR2 $(pgrep node)
```

---

## Disk {#disk}

**Alert:** `NodeDiskPressure`

```bash
# Find affected node
kubectl get nodes -o wide
kubectl describe node <node-name> | grep -A10 "Conditions"

# Check disk usage on node
kubectl debug node/<node-name> -it --image=ubuntu -- df -h /

# Clean up unused container images (DaemonSet or manual)
kubectl delete pods --field-selector=status.phase=Succeeded -A
kubectl delete pods --field-selector=status.phase=Failed -A

# For EBS-backed nodes — expand the volume via AWS Console or CLI
# aws ec2 modify-volume --volume-id vol-xxx --size 100
```

---

## Escalation

| Time without resolution | Action |
|-------------------------|--------|
| 15 min | Notify #platform-oncall |
| 30 min | Page on-call engineer |
| 45 min | Engage service owner + declare incident |

---

## Related Alerts

- `HighErrorRate`
- `PodCrashLooping`
- `HighMemorySaturation`

---

## Related Dashboards

- [Golden Signals Dashboard](http://grafana.monitoring.svc.cluster.local/d/golden-signals/golden-signals)
- [Kubernetes Nodes](http://grafana.monitoring.svc.cluster.local/d/1860)

---

## Post-Incident

Template: [postmortems/001.md](../docs/postmortems/001.md)
