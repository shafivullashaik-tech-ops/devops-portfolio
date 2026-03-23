#!/bin/bash
#
# post-apply-deploy.sh
# Deploys all platform services AFTER terraform apply completes
#
# Run this after: terraform apply
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
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}▶  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# ─── Step 1: Configure kubectl ────────────────────────────────────────────────
log_step "1/5  Configuring kubectl for EKS cluster"
aws eks update-kubeconfig \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --profile "${AWS_PROFILE}"

log_info "Verifying cluster connectivity..."
kubectl cluster-info
kubectl get nodes -o wide
log_info "kubectl configured ✓"

# ─── Step 2: Deploy ArgoCD ────────────────────────────────────────────────────
log_step "2/5  Deploying ArgoCD (GitOps engine)"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

GITOPS_DIR="${PROJECT_ROOT}/gitops-eks-platform"
BOOTSTRAP_DIR="${GITOPS_DIR}/bootstrap"

# kubectl apply -k requires a valid kustomization.yaml with ONLY the Kustomization document
# argocd-install.yaml contains a multi-doc YAML (Namespace + Kustomization) which is invalid
# So we generate a clean single-document kustomization.yaml
log_info "Generating clean kustomization.yaml for kubectl apply -k..."
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

kubectl apply -k "${BOOTSTRAP_DIR}" --server-side 2>/dev/null || \
    kubectl apply -k "${BOOTSTRAP_DIR}" --server-side --force-conflicts

log_info "Waiting for ArgoCD server to be ready (up to 5 min)..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

log_info "ArgoCD deployed ✓"
echo ""
echo -e "  ${YELLOW}ArgoCD URL:${NC}      kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo -e "  ${YELLOW}ArgoCD Username:${NC} admin"
echo -e "  ${YELLOW}ArgoCD Password:${NC} ${ARGOCD_PASSWORD}"
echo ""

# ─── Step 3: Deploy ArgoCD App-of-Apps ────────────────────────────────────────
log_step "3/5  Deploying App-of-Apps (bootstraps all platform services)"

kubectl apply -f "${GITOPS_DIR}/apps/app-of-apps.yaml"
log_info "App-of-Apps applied. ArgoCD will sync platform services automatically ✓"

# ─── Step 4: Deploy Monitoring Stack ──────────────────────────────────────────
# NOTE: Deploy monitoring BEFORE Jenkins so Prometheus CRDs exist for ServiceMonitor
log_step "4/5  Deploying Monitoring Stack (Prometheus + Grafana)"

# Always clean up any orphaned kube-prometheus-stack ClusterRoles/ClusterRoleBindings
# before installing. This handles leftover resources from any previous failed installs.
# Using --ignore-not-found so this is safe on a fresh cluster too.
log_info "Cleaning up any orphaned kube-prometheus-stack cluster-scoped resources..."

# Delete by label selectors (covers most cases)
kubectl delete clusterrole,clusterrolebinding \
    -l "app.kubernetes.io/instance=kube-prometheus-stack" \
    --ignore-not-found 2>/dev/null || true
kubectl delete clusterrole,clusterrolebinding \
    -l "release=kube-prometheus-stack" \
    --ignore-not-found 2>/dev/null || true

# Also delete known names explicitly (handles resources without proper labels)
for RESOURCE in \
    "clusterrole/kube-prometheus-stack-grafana-clusterrole" \
    "clusterrole/kube-prometheus-stack-kube-state-metrics" \
    "clusterrole/kube-prometheus-stack-operator" \
    "clusterrole/kube-prometheus-stack-prometheus" \
    "clusterrolebinding/kube-prometheus-stack-grafana-clusterrolebinding" \
    "clusterrolebinding/kube-prometheus-stack-kube-state-metrics" \
    "clusterrolebinding/kube-prometheus-stack-operator" \
    "clusterrolebinding/kube-prometheus-stack-prometheus"; do
    kubectl delete "${RESOURCE}" --ignore-not-found 2>/dev/null || true
done

# Delete namespace if it exists without a valid helm release (orphaned)
EXISTING_RELEASE=$(helm list -n monitoring --short 2>/dev/null | grep kube-prometheus-stack || true)
if [ -z "${EXISTING_RELEASE}" ] && kubectl get namespace monitoring &>/dev/null; then
    log_warn "Found orphaned monitoring namespace. Deleting..."
    kubectl delete namespace monitoring --wait=true 2>/dev/null || true
    log_info "Monitoring namespace deleted ✓"
fi

log_info "Cluster-scoped cleanup complete ✓"

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

MONITORING_VALUES="${PROJECT_ROOT}/sre-observability-stack/monitoring/kube-prometheus-stack/values.yaml"
if [ -f "${MONITORING_VALUES}" ]; then
    helm upgrade --install kube-prometheus-stack \
        prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values "${MONITORING_VALUES}" \
        --set grafana.persistence.storageClassName=gp2 \
        --set grafana.adminPassword="Admin@1234!" \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp2 \
        --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=gp2 \
        --wait \
        --timeout 20m
else
    helm upgrade --install kube-prometheus-stack \
        prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword="Admin@1234!" \
        --set grafana.persistence.enabled=false \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp2 \
        --wait \
        --timeout 20m
fi

log_info "Monitoring stack deployed ✓"

# ─── Step 5: Deploy Jenkins ───────────────────────────────────────────────────
log_step "5/5  Deploying Jenkins (CI engine)"

# Get Jenkins IRSA role ARN from Terraform output
JENKINS_IRSA_ARN=$(cd "${PROJECT_ROOT}/aws-platform-infra/terraform/environments/dev" && \
    terraform output -raw jenkins_irsa_role_arn 2>/dev/null || \
    echo "arn:aws:iam::${AWS_ACCOUNT_ID}:role/portfolio-eks-dev-jenkins-irsa")

log_info "Jenkins IRSA Role ARN: ${JENKINS_IRSA_ARN}"

# Update the IRSA annotation in jenkins-values.yaml dynamically
JENKINS_VALUES="${PROJECT_ROOT}/aws-platform-infra/jenkins/jenkins-values.yaml"
sed -i "s|eks.amazonaws.com/role-arn:.*|eks.amazonaws.com/role-arn: \"${JENKINS_IRSA_ARN}\"|" \
    "${JENKINS_VALUES}" 2>/dev/null || \
    log_warn "Could not update IRSA ARN in values file - update manually"

kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

helm repo add jenkins https://charts.jenkins.io
helm repo update

log_info "Installing Jenkins via Helm (this may take 5-10 min)..."
helm upgrade --install jenkins jenkins/jenkins \
    --namespace jenkins \
    --values "${JENKINS_VALUES}" \
    --wait \
    --timeout 15m

log_info "Jenkins deployed ✓"
bash "${SCRIPT_DIR}/get-jenkins-info.sh" jenkins || log_warn "Could not get Jenkins info yet - try again in 2 min"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅  All Platform Services Deployed!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Cluster:${NC}        ${CLUSTER_NAME} (${AWS_REGION})"
echo -e "${YELLOW}Account:${NC}        ${AWS_ACCOUNT_ID}"
echo -e "${YELLOW}ECR Registry:${NC}   ${ECR_URL}"
echo ""
echo -e "${YELLOW}Access Services:${NC}"
echo "  # ArgoCD"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  → https://localhost:8080  (admin / ${ARGOCD_PASSWORD})"
echo ""
echo "  # Jenkins"
echo "  kubectl port-forward svc/jenkins -n jenkins 8090:8080"
echo "  → http://localhost:8090  (admin / Admin@1234!)"
echo ""
echo "  # Grafana"
echo "  kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "  → http://localhost:3000  (admin / Admin@1234!)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Open ArgoCD → verify all apps are synced"
echo "  2. Open Jenkins → configure GitHub credentials (ID: github-credentials)"
echo "  3. Push a code change → watch the full CI/CD pipeline run!"
echo ""
echo -e "${YELLOW}When done testing - destroy to save costs:${NC}"
echo "  cd aws-platform-infra/terraform/environments/dev"
echo "  terraform destroy"
echo ""
