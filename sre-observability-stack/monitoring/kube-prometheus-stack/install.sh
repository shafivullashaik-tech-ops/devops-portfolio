#!/usr/bin/env bash
# =============================================================
# install.sh — kube-prometheus-stack idempotent installer
# Usage: bash monitoring/kube-prometheus-stack/install.sh
# =============================================================
set -euo pipefail

NAMESPACE="monitoring"
RELEASE="kube-prometheus-stack"
CHART="prometheus-community/kube-prometheus-stack"
CHART_VERSION="58.4.0"   # Pin to a stable version
VALUES_FILE="$(dirname "$0")/values.yaml"

# ── Colours ─────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Pre-flight checks ────────────────────────────────────────
command -v helm   >/dev/null 2>&1 || error "helm not found. Install helm 3+"
command -v kubectl >/dev/null 2>&1 || error "kubectl not found."

info "Current kubectl context: $(kubectl config current-context)"
read -r -p "Continue with this context? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || error "Aborted."

# ── Add Helm repo ────────────────────────────────────────────
info "Adding prometheus-community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# ── Create namespace ─────────────────────────────────────────
info "Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── Create Grafana admin secret ──────────────────────────────
info "Creating Grafana admin secret (if not exists)..."
if ! kubectl -n "$NAMESPACE" get secret grafana-admin-secret >/dev/null 2>&1; then
  GRAFANA_PASSWORD=$(openssl rand -base64 24)
  kubectl -n "$NAMESPACE" create secret generic grafana-admin-secret \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$GRAFANA_PASSWORD"
  info "Grafana admin password: $GRAFANA_PASSWORD  ← SAVE THIS"
else
  warn "grafana-admin-secret already exists — skipping creation."
fi

# ── Install / Upgrade ────────────────────────────────────────
info "Installing / upgrading $RELEASE (chart $CHART_VERSION)..."
helm upgrade --install "$RELEASE" "$CHART" \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --values "$VALUES_FILE" \
  --set grafana.admin.existingSecret=grafana-admin-secret \
  --set grafana.admin.userKey=admin-user \
  --set grafana.admin.passwordKey=admin-password \
  --atomic \
  --timeout 10m \
  --wait

# ── Apply custom PrometheusRule (Golden Signals) ─────────────
RULES_FILE="$(dirname "$0")/../alerts/golden-signals-rules.yaml"
if [[ -f "$RULES_FILE" ]]; then
  info "Applying Golden Signals PrometheusRules..."
  kubectl apply -f "$RULES_FILE"
fi

# ── Apply Golden Signals dashboard ConfigMap ─────────────────
DASH_FILE="$(dirname "$0")/../dashboards/golden-signals-configmap.yaml"
if [[ -f "$DASH_FILE" ]]; then
  info "Applying Golden Signals Grafana dashboard..."
  kubectl apply -f "$DASH_FILE"
fi

# ── Status ───────────────────────────────────────────────────
info "Waiting for Grafana pod to be ready..."
kubectl -n "$NAMESPACE" wait --for=condition=ready pod \
  -l "app.kubernetes.io/name=grafana" --timeout=300s

info "✅ kube-prometheus-stack installed successfully!"
echo ""
echo "  Grafana:      kubectl port-forward -n $NAMESPACE svc/kube-prometheus-grafana 3000:80"
echo "  Prometheus:   kubectl port-forward -n $NAMESPACE svc/kube-prometheus-kube-prome-prometheus 9090:9090"
echo "  Alertmanager: kubectl port-forward -n $NAMESPACE svc/kube-prometheus-kube-prome-alertmanager 9093:9093"
