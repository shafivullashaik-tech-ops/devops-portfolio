# GitOps Platform - ArgoCD Configuration

GitOps configurations for managing Kubernetes deployments with ArgoCD.

## Structure

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
    └── ingress-nginx/
```

## Deployment

### Install ArgoCD

```bash
# Apply ArgoCD installation
kubectl apply -k bootstrap/

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Deploy Applications

```bash
# Apply root application (manages all apps)
kubectl apply -f apps/app-of-apps.yaml
```

## GitOps Workflow

```
Developer → Git Push → Jenkins (CI) → Build/Test/Scan → Push ECR
                                            ↓
                              Update GitOps Repo (image tag)
                                            ↓
                              ArgoCD Detects Change
                                            ↓
                              Sync to Kubernetes
```

## App-of-Apps Pattern

The `app-of-apps.yaml` manages all applications:
- Platform services (monitoring, ingress)
- Application deployments
- Environment-specific configurations

## Environment Management

Each environment has separate configurations:

**Dev:**
- Lower replica count
- Reduced resource limits
- Auto-sync enabled

**Prod:**
- Higher replica count
- Production resource limits
- Manual sync approval

## Sync Policies

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Revert manual changes
  syncOptions:
    - CreateNamespace=true
```

## Security

- No secrets in Git (use External Secrets Operator or Sealed Secrets)
- RBAC limits ArgoCD permissions per project
- Git SSH with deploy keys
- Only deploy scanned images
- Network policies enforced

## Monitoring

ArgoCD exposes Prometheus metrics:
- `argocd_app_sync_total` - Total sync operations
- `argocd_app_health_status` - Application health
- `argocd_app_sync_duration_seconds` - Sync duration
