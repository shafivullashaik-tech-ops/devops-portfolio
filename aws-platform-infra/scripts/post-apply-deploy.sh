#!/bin/bash
#
# post-apply-deploy.sh
# GitOps Bootstrap Script — runs AFTER terraform apply
#
# This script ONLY bootstraps ArgoCD.
# After ArgoCD is running, it reads the App-of-Apps from Git and
# automatically deploys EVERYTHING: Monitoring, Jenkins, Applications.
#
# Enterprise GitOps flow:
#   Terraform → EKS cluster
#   This script → Bootstrap ArgoCD only
#   ArgoCD → Reads Git → Deploys: kube-prometheus-stack, Jenkins, demo-app, loki-stack
#
# Usage: ./post-apply-deploy.sh [aws-region]
# Example: ./post-apply-deploy.sh us-west-2
#

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
AWS_REGION=${1:-us-west-2}
AWS_PROFILE="shafi"
CLUSTER_NAME="portfolio-eks-dev"
AWS_ACCOUNT_ID="050451393596"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GITOPS_DIR="${PROJECT_ROOT}/gitops-eks-platform"
BOOTSTRAP_DIR="${GITOPS_DIR}/bootstrap"

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}▶  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║        🚀 GitOps Bootstrap — DevOps Portfolio               ║
║                                                              ║
║   Step 1: kubectl → EKS                                      ║
║   Step 2: Bootstrap ArgoCD                                   ║
║   Step 3: Apply App-of-Apps                                  ║
║   Step 4: ArgoCD takes over → deploys everything from Git    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ─── Step 1: Configure kubectl ────────────────────────────────────────────────
log_step "1/3  Configuring kubectl for EKS cluster"

aws eks update-kubeconfig \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --profile "${AWS_PROFILE}"

log_info "Verifying cluster connectivity..."
kubectl cluster-info
kubectl get nodes -o wide
log_info "kubectl configured ✓"

# ─── Step 2: Bootstrap ArgoCD ─────────────────────────────────────────────────
log_step "2/3  Bootstrapping ArgoCD (GitOps engine)"

# Create argocd namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Generate a clean single-document kustomization.yaml
# (kustomize requires exactly ONE document of kind Kustomization)
log_info "Generating clean kustomization.yaml..."
cat > "${BOOTSTRAP_DIR}/kustomization.yaml" <<'KUSTOMIZATION'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd

resources:
  - https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

patches:
  - patch: |-
      - op: replace
        path: /spec/type
        value: LoadBalancer
    target:
      kind: Service
      name: argocd-server
KUSTOMIZATION

# Apply ArgoCD (idempotent - safe to run multiple times)
log_info "Installing ArgoCD..."
kubectl apply -k "${BOOTSTRAP_DIR}" --server-side 2>/dev/null || \
    kubectl apply -k "${BOOTSTRAP_DIR}" --server-side --force-conflicts

# Wait for ArgoCD server to be ready
log_info "Waiting for ArgoCD server to be ready (up to 5 min)..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

log_info "ArgoCD bootstrapped ✓"
echo ""
echo -e "  ${YELLOW}ArgoCD URL:${NC}      kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo -e "  ${YELLOW}Username:${NC}        admin"
echo -e "  ${YELLOW}Password:${NC}        ${ARGOCD_PASSWORD}"
echo ""

# ─── Step 3: Apply App-of-Apps ────────────────────────────────────────────────
log_step "3/3  Applying App-of-Apps (hands off to GitOps)"

# Apply the root App-of-Apps
# This single manifest tells ArgoCD to watch Git and deploy EVERYTHING:
#   - kube-prometheus-stack (Prometheus + Grafana)
#   - Jenkins
#   - loki-stack (logs)
#   - demo-app
kubectl apply -f "${GITOPS_DIR}/apps/app-of-apps.yaml"

log_info "App-of-Apps applied ✓"
log_info "ArgoCD is now syncing all platform services from Git..."

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅  Bootstrap Complete — ArgoCD is taking over!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}What ArgoCD will deploy automatically from Git:${NC}"
echo "  📊 kube-prometheus-stack  → Prometheus + Grafana (namespace: monitoring)"
echo "  🔵 loki-stack             → Log aggregation     (namespace: logging)"
echo "  🔧 Jenkins                → CI engine           (namespace: jenkins)"
echo "  🚀 demo-app               → Sample application  (namespace: default)"
echo ""
echo -e "${YELLOW}Monitor ArgoCD sync progress:${NC}"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  → https://localhost:8080  (admin / ${ARGOCD_PASSWORD})"
echo ""
echo -e "${YELLOW}Check sync status via CLI:${NC}"
echo "  kubectl get applications -n argocd"
echo "  kubectl get pods --all-namespaces"
echo ""
echo -e "${YELLOW}Once synced, access services:${NC}"
echo "  # Grafana"
echo "  kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "  → http://localhost:3000  (admin / Admin@1234!)"
echo ""
echo "  # Jenkins"
echo "  kubectl port-forward svc/jenkins -n jenkins 8090:8080"
echo "  → http://localhost:8090  (admin / run: kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password)"
echo ""
echo -e "${YELLOW}When done testing - destroy to save costs (~\$185/month):${NC}"
echo "  cd aws-platform-infra/terraform/environments/dev"
echo "  terraform destroy"
echo ""
