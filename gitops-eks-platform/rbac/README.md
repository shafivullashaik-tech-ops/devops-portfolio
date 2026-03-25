# 🔐 Enterprise-Grade EKS RBAC

Complete Kubernetes RBAC implementation for the DevOps Portfolio EKS cluster.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `aws-auth-configmap.yaml` | **Bridge**: Maps AWS IAM roles/users → K8s groups |
| `cluster-roles.yaml` | Defines 6 cluster-wide roles (what each role CAN do) |
| `cluster-role-bindings.yaml` | Binds cluster-wide roles to AWS IAM groups |
| `namespace-role-bindings.yaml` | Namespace-specific bindings per team |
| `service-accounts.yaml` | Per-app ServiceAccounts with IRSA annotations |
| `kustomization.yaml` | Applies all files in correct order |

---

## 🏗️ RBAC Architecture

```
AWS IAM Identity (SSO Role / User)
         │
         │  aws eks update-kubeconfig
         ▼
┌─────────────────────────────────────┐
│        aws-auth ConfigMap           │  ← kube-system namespace
│  mapRoles / mapUsers                │
│  IAM Role ARN → K8s Group           │
└─────────────────────────────────────┘
         │
         │  K8s Group assigned
         ▼
┌─────────────────────────────────────┐
│     ClusterRoleBinding / RoleBinding│  ← K8s RBAC
│  Group → ClusterRole / Role         │
└─────────────────────────────────────┘
         │
         │  Permissions granted
         ▼
┌─────────────────────────────────────┐
│     ClusterRole / Role              │
│  resources + verbs defined          │
└─────────────────────────────────────┘
```

---

## 👥 Role Hierarchy

| Role | Who Uses It | Scope | Permissions |
|------|------------|-------|-------------|
| `platform-admin` | DevOps team leads | Cluster-wide | Full cluster (`*`) |
| `sre` | On-call engineers | Cluster-wide | Read-all + restart pods + exec + scale |
| `namespace-admin` | Team leads | Per-namespace | Full admin in 1 namespace |
| `developer` | App developers | Per-namespace | Deploy, debug, logs, exec |
| `readonly` | Auditors, managers | Cluster-wide | View-only (no secrets) |
| `cicd-deployer` | Jenkins, ArgoCD | Cluster-wide | Deploy workloads only |

---

## 🗂️ Namespace Access Matrix

| IAM Group | default | llmops | monitoring | jenkins | argocd |
|-----------|---------|--------|------------|---------|--------|
| `eks-platform-admins` | admin | admin | admin | **ns-admin** | **ns-admin** |
| `eks-sre-team` | sre | sre | **developer** | readonly | **developer** |
| `eks-sre-team-leads` | sre | sre | **ns-admin** | readonly | developer |
| `eks-demo-team-leads` | **ns-admin** | — | readonly | readonly | readonly |
| `eks-demo-developers` | developer | — | readonly | readonly | readonly |
| `eks-llmops-team-leads` | — | **ns-admin** | readonly | readonly | readonly |
| `eks-llmops-developers` | — | developer | readonly | readonly | readonly |

---

## 🔑 Service Accounts + IRSA

| ServiceAccount | Namespace | AWS Permissions (IRSA) |
|----------------|-----------|----------------------|
| `llm-gateway` | llmops | S3 (model storage) + Secrets Manager (API keys) |
| `demo-app` | default | None (no AWS access needed) |
| `jenkins` | jenkins | ECR push + S3 artifacts + EKS describe |
| `argocd-image-updater` | argocd | ECR read (auto-detect new image tags) |
| `prometheus` | monitoring | S3 write (long-term metrics storage) |
| `loki` | monitoring | S3 read/write (log chunk storage) |

---

## 🚀 How to Apply

```bash
# Apply all RBAC resources at once
kubectl apply -k gitops-eks-platform/rbac/

# Or apply individually in order:
kubectl apply -f gitops-eks-platform/rbac/aws-auth-configmap.yaml
kubectl apply -f gitops-eks-platform/rbac/cluster-roles.yaml
kubectl apply -f gitops-eks-platform/rbac/cluster-role-bindings.yaml
kubectl apply -f gitops-eks-platform/rbac/namespace-role-bindings.yaml
kubectl apply -f gitops-eks-platform/rbac/service-accounts.yaml
```

---

## ✅ Verify Access

```bash
# List all ClusterRoles we created
kubectl get clusterroles | grep -E "platform-admin|developer|sre|readonly|cicd-deployer|namespace-admin"

# List all ClusterRoleBindings
kubectl get clusterrolebindings | grep -E "platform-admins|sre-team|readonly-users|argocd|prometheus"

# List all RoleBindings per namespace
kubectl get rolebindings -n default
kubectl get rolebindings -n llmops
kubectl get rolebindings -n monitoring
kubectl get rolebindings -n jenkins
kubectl get rolebindings -n argocd

# Test: Can SRE delete a pod? (should be YES)
kubectl auth can-i delete pods --namespace=default --as-group=eks-sre-team

# Test: Can developer list pods in default? (should be YES)
kubectl auth can-i list pods --namespace=default --as-group=eks-demo-developers

# Test: Can developer delete pods in monitoring? (should be NO)
kubectl auth can-i delete pods --namespace=monitoring --as-group=eks-demo-developers

# Test: Can readonly list secrets? (should be NO — intentionally excluded)
kubectl auth can-i list secrets --namespace=default --as-group=eks-readonly

# Test: Can platform-admin do everything? (should be YES)
kubectl auth can-i "*" "*" --as-group=eks-platform-admins
```

---

## 🔒 Security Best Practices Applied

| Practice | Implementation |
|----------|---------------|
| **Least privilege** | Each role has only the minimum verbs needed |
| **Namespace isolation** | Developers can only access their own namespace |
| **No secret access for readonly** | Auditors cannot view secret contents |
| **IRSA over node roles** | Pods get own AWS IAM role, not the node's role |
| **No `automountServiceAccountToken`** | Disabled for apps that don't call K8s API |
| **Named resource restrictions** | LLM gateway can only read its own ConfigMap/Secret |
| **Separate CI/CD role** | Jenkins/ArgoCD use `cicd-deployer`, not `cluster-admin` |
| **GitOps managed** | All RBAC in Git — no manual `kubectl` changes |

---

## 📋 AWS IAM Groups to Create

Create these IAM groups in your AWS account and add users to them:

```bash
# Create IAM groups
aws iam create-group --group-name eks-platform-admins
aws iam create-group --group-name eks-sre-team
aws iam create-group --group-name eks-sre-team-leads
aws iam create-group --group-name eks-readonly
aws iam create-group --group-name eks-demo-developers
aws iam create-group --group-name eks-demo-team-leads
aws iam create-group --group-name eks-llmops-developers
aws iam create-group --group-name eks-llmops-team-leads

# Add yourself to platform-admins
aws iam add-user-to-group \
  --user-name shafivullashaik-tech-ops \
  --group-name eks-platform-admins
```

---

## ⚠️ Before Applying: Replace Placeholders

1. In `aws-auth-configmap.yaml`:
   - Replace `ACCOUNT_ID` with your AWS Account ID (12 digits)
   - Replace `XXXXXXXX` in SSO role names with actual SSO assignment IDs
   - Run: `aws sts get-caller-identity --query Account --output text`

2. In `service-accounts.yaml`:
   - Replace `ACCOUNT_ID` in all IRSA `role-arn` annotations
   - Ensure IAM roles exist (created by Terraform in `terraform-aws-modules/iam/`)
