# GitOps Platform - ArgoCD Configuration

This repository contains GitOps configurations for managing Kubernetes deployments via ArgoCD.

## 🎯 What is GitOps?

GitOps is a modern approach to Continuous Deployment where:
- **Git is the single source of truth** for infrastructure and applications
- **Declarative configuration** defines desired state
- **Automated sync** keeps cluster matching Git state
- **Easy rollbacks** via git revert
- **Full audit trail** via Git history

## 🏗️ Repository Structure

```
gitops-eks-platform/
├── bootstrap/              # ArgoCD installation
│   └── argocd-install.yaml
├── apps/                   # Application definitions
│   ├── app-of-apps.yaml    # Root application
│   └── demo-app.yaml       # Sample application
├── environments/           # Environment-specific configs
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── values.yaml
└── platform-services/      # Cluster services
    ├── monitoring/
    │   ├── prometheus/
    │   └── grafana/
    └── ingress-nginx/
```

## 🚀 Quick Start

### Step 1: Install ArgoCD

```bash
# Apply ArgoCD installation
kubectl apply -k bootstrap/

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Step 2: Deploy App-of-Apps

```bash
# Apply root application
kubectl apply -f apps/app-of-apps.yaml

# ArgoCD will automatically deploy all applications
```

### Step 3: Deploy Demo Application

```bash
# The demo app is managed by ArgoCD
# When Jenkins updates the image tag in environments/dev/values.yaml,
# ArgoCD automatically syncs the change to Kubernetes
```

## 🔄 How GitOps Works in This Portfolio

```
Developer → Git Push → GitHub
                         ↓
                    Jenkins (CI)
                         ↓
                   Build + Test + Scan
                         ↓
                    Push to ECR
                         ↓
           Update GitOps Repo (this repo)
                         ↓
                    ArgoCD Detects Change
                         ↓
                    Sync to Kubernetes
                         ↓
                    Application Updated
```

## 📝 Key Concepts

### App-of-Apps Pattern

The `app-of-apps.yaml` is the root application that manages all other applications:
- Platform services (monitoring, ingress)
- Application deployments
- Environment-specific configurations

This provides:
- Single source of truth
- Consistent deployment across environments
- Easy addition of new applications

### Environment Management

Each environment (dev, prod) has:
- `kustomization.yaml` - Kustomize configuration
- `values.yaml` - Environment-specific values

```yaml
# environments/dev/values.yaml
replicaCount: 2
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"

# environments/prod/values.yaml
replicaCount: 5
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
```

### Sync Policies

ArgoCD sync policies control automated deployment:

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Revert manual changes
  syncOptions:
    - CreateNamespace=true
```

## 🎤 Interview Talking Points

### Q: "Why GitOps over traditional CD?"

**A**: "GitOps provides several advantages:

1. **Declarative**: Desired state in Git, not imperative scripts
2. **Version Control**: Every deployment is a Git commit with full history
3. **Rollback**: Simple `git revert` to roll back any change
4. **Audit Trail**: Who deployed what and when
5. **Security**: No kubectl access needed from CI tools
6. **Drift Detection**: ArgoCD detects manual changes

Traditional CD tools like Jenkins push changes via `kubectl apply`. GitOps uses a pull model where ArgoCD continuously reconciles cluster state with Git."

### Q: "How do you handle secrets in GitOps?"

**A**: "Secrets should never be in Git. We use:

1. **Sealed Secrets**: Encrypt secrets that can be safely stored in Git
2. **External Secrets Operator**: Sync from AWS Secrets Manager
3. **SOPS**: Encrypt specific values in YAML files
4. **Vault**: Central secret management

For this portfolio, I'd use External Secrets Operator:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: app-secrets
  data:
  - secretKey: api-key
    remoteRef:
      key: prod/api-key
```"

### Q: "What happens if ArgoCD is down?"

**A**: "Applications continue running normally. ArgoCD only manages deployments:

- Existing apps keep running
- No new deployments happen
- Manual kubectl still works (but creates drift)

When ArgoCD comes back:
- Resumes syncing
- Detects any drift
- Reconciles to Git state

For HA, ArgoCD should run with multiple replicas and proper resource requests."

### Q: "How do you test GitOps changes?"

**A**: "Multi-layered approach:

1. **Syntax Validation**: `kubectl apply --dry-run=client`
2. **Kustomize Build**: `kustomize build` to check templates
3. **ArgoCD Diff**: Preview changes before sync
4. **Staging Environment**: Test in dev before prod
5. **Progressive Rollouts**: Canary deployments with Argo Rollouts
6. **Automated Rollback**: If health checks fail

Example workflow:
```bash
# Test locally
kustomize build environments/dev | kubectl apply --dry-run=client -f -

# Commit and push
git commit -m "Update deployment"
git push

# Preview in ArgoCD
argocd app diff demo-app

# Sync
argocd app sync demo-app
```"

## 🔒 Security Best Practices

1. **No Secrets in Git**: Use External Secrets Operator or Sealed Secrets
2. **RBAC**: Limit ArgoCD permissions per project
3. **Git SSH**: Use deploy keys, not personal credentials
4. **Image Scanning**: Only deploy scanned images
5. **Pod Security**: Enforce PSS/PSP
6. **Network Policies**: Restrict pod-to-pod traffic

## 📊 Monitoring ArgoCD

Key metrics to track:
- **Sync Status**: Are applications in sync?
- **Health Status**: Are applications healthy?
- **Sync Duration**: How long does sync take?
- **Sync Failures**: Why are syncs failing?

ArgoCD provides Prometheus metrics:
```
argocd_app_sync_total
argocd_app_health_status
argocd_app_sync_duration_seconds
```

## 🗺️ Next Steps

1. **Add Applications**: Create new apps in `apps/`
2. **Add Environments**: Create new environments in `environments/`
3. **Add Platform Services**: Add monitoring, logging, etc.
4. **Implement Rollouts**: Add canary deployments with Argo Rollouts
5. **Add Notifications**: Configure Slack/email notifications

## 📖 Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)

---

**Status**: Template structure ready for ArgoCD deployment
**Next**: Add actual manifests for demo application
