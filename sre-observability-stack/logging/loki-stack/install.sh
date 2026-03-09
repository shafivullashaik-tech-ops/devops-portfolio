#!/bin/bash
# install.sh - Deploy Loki Stack for log aggregation
# Usage: bash sre-observability-stack/logging/loki-stack/install.sh

set -euo pipefail

NAMESPACE="logging"
RELEASE="loki-stack"
GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }

log "Adding grafana helm repo..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

log "Creating logging namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

log "Installing Loki Stack (Loki + Promtail)..."
helm upgrade --install ${RELEASE} grafana/loki-stack \
  --namespace ${NAMESPACE} \
  --values "$(dirname "$0")/values.yaml" \
  --set loki.persistence.storageClassName=gp2 \
  --wait --timeout 10m

log "Verifying Loki is running..."
kubectl get pods -n ${NAMESPACE}

echo ""
echo -e "${GREEN}✅ Loki Stack deployed!${NC}"
echo ""
echo "Add Loki as datasource in Grafana:"
echo "  URL: http://loki-stack.logging.svc.cluster.local:3100"
echo "  Type: Loki"
echo ""
echo "Query logs in Grafana Explore:"
echo "  {namespace=\"default\", pod=~\"demo-app.*\"}"
