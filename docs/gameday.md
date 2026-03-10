# GameDay Runbook — DevOps Portfolio

**Date:** 2026-03-09
**Environment:** `portfolio-eks-dev` (us-west-2)
**Participants:** Platform Engineering
**Objectives:** Validate detection → mitigation → postmortem flow

---

## Prerequisites

```bash
# Ensure cluster access
kubectl get nodes

# Ensure monitoring is running
kubectl get pods -n monitoring

# Ensure demo-app is running
kubectl get pods -n default

# Install k6 for load testing
# https://k6.io/docs/getting-started/installation/
```

---

## Scenario 1: CrashLoop Injection

### Objective
Verify `PodCrashLooping` alert fires and runbook resolves the issue.

### Inject Failure
```bash
# Patch demo-app to use a bad command (forces crash)
kubectl patch deployment demo-app -n default --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c","exit 1"]}]'

# Watch pods crash
kubectl get pods -n default -w
```

### Expected Detection
- Within 5 minutes: `PodCrashLooping` alert fires in Alertmanager
- Alert links to runbook: `sre-observability-stack/runbooks/crashloop.md`
- Grafana dashboard shows restart count spike

### Mitigation
```bash
# Rollback to previous version
kubectl rollout undo deployment/demo-app -n default

# Verify recovery
kubectl rollout status deployment/demo-app -n default
kubectl get pods -n default
```

### Verify Alert Resolution
- Check Alertmanager: alert moves to `Resolved` state
- Grafana: restart count returns to 0

---

## Scenario 2: High Error Rate Injection

### Objective
Verify `HighErrorRate` alert fires during elevated 5xx responses.

### Load Test with k6
```bash
# Run k6 load test against demo-app
k6 run sre-observability-stack/load-tests/high-error-rate.js
```

### Inject Failure (Manual)
```bash
# Temporarily scale down to 0 replicas (simulates outage)
kubectl scale deployment demo-app -n default --replicas=0

# Or introduce a bad env var causing 500s
kubectl set env deployment/demo-app -n default APP_FORCE_ERROR=true
```

### Expected Detection
- `HighErrorRate` alert fires (>5% 5xx for 5 min)
- Grafana shows error rate spike on Golden Signals dashboard

### Mitigation
```bash
kubectl scale deployment demo-app -n default --replicas=2
# OR
kubectl set env deployment/demo-app -n default APP_FORCE_ERROR-
```

---

## Scenario 3: High Latency Injection

### Objective
Verify `HighP99Latency` alert fires during slow responses.

### Load Test with k6
```bash
k6 run sre-observability-stack/load-tests/high-latency.js
```

### Inject Failure (Manual)
```bash
# Add artificial delay env var
kubectl set env deployment/demo-app -n default APP_LATENCY_MS=2000
```

### Expected Detection
- `HighP99Latency` alert fires (P99 > 1s for 5 min)

### Mitigation
```bash
kubectl set env deployment/demo-app -n default APP_LATENCY_MS-
```

---

## Scenario 4: Pod Kill (Chaos)

### Objective
Verify Kubernetes self-healing and no alert fires if replicas > 1.

```bash
# Kill one pod
kubectl delete pod -n default -l app.kubernetes.io/name=demo-app --wait=false

# Watch Kubernetes recreate it
kubectl get pods -n default -w
```

### Expected Outcome
- No `PodCrashLooping` alert (graceful restart, not crash)
- Pod recreated within 30 seconds
- No user-facing downtime (other replica handles traffic)

---

## Observations Template

| Scenario | Alert Fired? | Time to Detect | Time to Resolve | Notes |
|----------|-------------|----------------|-----------------|-------|
| CrashLoop | ✅/❌ | ~X min | ~X min | |
| High Error Rate | ✅/❌ | ~X min | ~X min | |
| High Latency | ✅/❌ | ~X min | ~X min | |
| Pod Kill | N/A | N/A | ~30s | Self-healed |

---

## Post-GameDay

1. Create postmortem for any scenario that took > 15 min to resolve
2. Update runbooks with lessons learned
3. File issues for any gaps found in alerting/tooling
4. Template: [docs/postmortems/001.md](postmortems/001.md)
