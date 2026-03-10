#!/bin/bash
# install.sh - Deploy Tempo (traces) + OpenTelemetry Collector
# Usage: bash sre-observability-stack/tracing/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="monitoring"
GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }

log "Adding grafana helm repo..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

log "Installing Tempo (trace backend)..."
helm upgrade --install tempo grafana/tempo \
  --namespace ${NAMESPACE} \
  --values "${SCRIPT_DIR}/tempo-values.yaml" \
  --wait --timeout 5m

log "Deploying OpenTelemetry Collector..."
kubectl apply -f "${SCRIPT_DIR}/otel-collector.yaml"

log "Waiting for OTel Collector to be ready..."
kubectl wait --for=condition=available --timeout=120s \
  deployment/otel-collector -n ${NAMESPACE}

echo ""
echo -e "${GREEN}✅ Tracing stack deployed!${NC}"
echo ""
echo "Configure your app to send traces to:"
echo "  OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.monitoring.svc.cluster.local:4318"
echo ""
echo "Add Tempo datasource in Grafana:"
echo "  URL: http://tempo.monitoring.svc.cluster.local:3100"
echo "  Type: Tempo"
echo ""
echo "Correlate with Loki by adding derived field:"
echo "  Field name: trace_id"
echo "  Regex: '\"trace_id\":\"(\w+)\"'"
echo "  Internal link: Tempo datasource"
