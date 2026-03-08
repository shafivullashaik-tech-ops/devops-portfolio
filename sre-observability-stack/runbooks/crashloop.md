# Runbook: PodCrashLooping / CrashLoopBackOff

**Alert:** `PodCrashLooping`
**Severity:** Critical
**Category:** Availability
**Owner:** Platform Engineering
**Last Updated:** 2026-03-06

---

## Summary

A container is restarting more than 3 times in 15 minutes. Kubernetes is stuck in a
`CrashLoopBackOff` cycle: it keeps trying to start the container, but the container keeps dying.

---

## Impact

| Signal | Effect |
|--------|--------|
| Pod unavailable | Requests routed to remaining replicas (if any) |
| All replicas crashing | Full service outage |
| OOMKilled | Memory over-limit — likely memory leak |

---

## Diagnosis Steps

### 1. Identify the affected pod

```bash
# See pods in CrashLoop
kubectl get pods -A | grep -E "CrashLoop|Error|OOMKilled"

# Narrow to namespace from alert label
kubectl get pods -n <namespace> -o wide
```

### 2. Read current and previous container logs

```bash
# Current logs (may be short if crash is immediate)
kubectl logs -n <namespace> <pod-name> --tail=100

# Previous container (before last restart) — most useful
kubectl logs -n <namespace> <pod-name> --previous --tail=200

# Follow live
kubectl logs -n <namespace> <pod-name> -f
```

### 3. Describe the pod for events

```bash
kubectl describe pod -n <namespace> <pod-name>
# Look at:
#   Events section  — OOMKilled, Liveness probe failed, etc.
#   Last State      — Exit code, reason
#   Restart Count
```

### 4. Common exit codes

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 0 | Normal exit (process exited cleanly) | Check if CMD is correct |
| 1 | General application error | Check app logs |
| 137 | OOMKilled (SIGKILL) | Increase memory limit |
| 139 | Segfault | Check for native library issues |
| 143 | SIGTERM not handled | Fix graceful shutdown |

### 5. Check recent deployments / config changes

```bash
# Recent rollout history
kubectl rollout history deployment/<name> -n <namespace>

# Check if a bad config was deployed
kubectl describe deployment/<name> -n <namespace>

# Check ConfigMap and Secret mounts
kubectl get configmap,secret -n <namespace>
```

### 6. Check resource limits

```bash
kubectl get pod <pod-name> -n <namespace> -o json \
  | jq '.spec.containers[].resources'
```

---

## Mitigation

### Option A — Rollback the deployment (if caused by a bad release)

```bash
# Roll back to previous version
kubectl rollout undo deployment/<name> -n <namespace>

# Verify rollout
kubectl rollout status deployment/<name> -n <namespace>
```

### Option B — Increase memory limit (if OOMKilled)

```bash
kubectl patch deployment <name> -n <namespace> --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"512Mi"}]'
```

### Option C — Fix bad environment variable / secret

```bash
# Check env vars for errors
kubectl exec -n <namespace> <pod-name> -- env | grep -i "db\|secret\|password"

# If secret is missing
kubectl get secret <secret-name> -n <namespace>
```

### Option D — Temporary: increase restart delay (buy time)

```bash
# Scale down, fix, scale back
kubectl scale deployment <name> -n <namespace> --replicas=0
# ... fix the issue ...
kubectl scale deployment <name> -n <namespace> --replicas=2
```

---

## OOMKilled

**Alert:** `PodOOMKilled`

### Diagnosis

```bash
# Confirm OOMKill
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Last State"
# Last State: Terminated
#   Reason: OOMKilled

# Check current memory usage
kubectl top pod <pod-name> -n <namespace>

# Check Loki logs for memory leak signals
# Query: {namespace="<ns>", pod="<pod>"} |= "heap" | json
```

### Mitigation

1. Increase `resources.limits.memory` in the Helm values and redeploy
2. Check for memory leak: monitor heap usage over time in Grafana
3. If app allocates buffers, tune buffer sizes via env vars

---

## Escalation

| Time without resolution | Action |
|-------------------------|--------|
| 15 min | Notify #incidents Slack channel |
| 30 min | Page on-call engineer |
| 45 min | Engage service owner |

---

## Related Alerts

- `PodOOMKilled`
- `DeploymentReplicasUnavailable`
- `HighErrorRate`

---

## Related Dashboards

- [Golden Signals Dashboard](http://grafana.monitoring.svc.cluster.local/d/golden-signals/golden-signals)
- [Kubernetes Pods](http://grafana.monitoring.svc.cluster.local/d/6417)

---

## Post-Incident

After resolving, open a postmortem if:
- Outage > 15 minutes
- Multiple replicas affected
- Root cause is not immediately obvious

Template: [postmortems/001.md](../docs/postmortems/001.md)
