#!/bin/bash
#
# get-jenkins-info.sh
# Retrieves Jenkins URL and initial admin password from Kubernetes
#
# Usage: ./get-jenkins-info.sh [namespace]
# Example: ./get-jenkins-info.sh jenkins
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed. Please install it first."
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    log_error "Make sure kubectl is configured with: aws eks update-kubeconfig --name <cluster-name>"
    exit 1
fi

NAMESPACE=${1:-jenkins}

log_info "Retrieving Jenkins information from namespace: ${NAMESPACE}"
echo ""

# Check if namespace exists
if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
    log_error "Namespace '${NAMESPACE}' does not exist"
    exit 1
fi

# Check if Jenkins pod is running
log_info "Checking Jenkins pod status..."
JENKINS_POD=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "${JENKINS_POD}" ]; then
    log_error "Jenkins pod not found in namespace '${NAMESPACE}'"
    log_error "Make sure Jenkins is deployed"
    exit 1
fi

POD_STATUS=$(kubectl get pod "${JENKINS_POD}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}')
if [ "${POD_STATUS}" != "Running" ]; then
    log_warn "Jenkins pod is not running yet (Status: ${POD_STATUS})"
    log_info "Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod/"${JENKINS_POD}" -n "${NAMESPACE}" --timeout=300s
fi

log_info "Jenkins pod is running: ${JENKINS_POD}"
echo ""

# Get Jenkins URL
log_info "Getting Jenkins URL..."
SERVICE_TYPE=$(kubectl get svc -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].spec.type}')

if [ "${SERVICE_TYPE}" = "LoadBalancer" ]; then
    JENKINS_URL=$(kubectl get svc -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
    if [ -z "${JENKINS_URL}" ]; then
        JENKINS_URL=$(kubectl get svc -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
    fi

    if [ -z "${JENKINS_URL}" ]; then
        log_warn "LoadBalancer URL not yet assigned. Waiting..."
        kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' svc -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller --timeout=300s
        JENKINS_URL=$(kubectl get svc -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
        if [ -z "${JENKINS_URL}" ]; then
            JENKINS_URL=$(kubectl get svc -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
        fi
    fi

    JENKINS_PORT=$(kubectl get svc -n "${NAMESPACE}" -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].spec.ports[?(@.name=="http")].port}')
    FULL_JENKINS_URL="http://${JENKINS_URL}:${JENKINS_PORT}"
else
    log_warn "Jenkins service type is ${SERVICE_TYPE}, not LoadBalancer"
    log_info "You can access Jenkins via port-forward:"
    echo ""
    echo "  kubectl port-forward -n ${NAMESPACE} svc/jenkins 8080:8080"
    echo ""
    FULL_JENKINS_URL="http://localhost:8080"
fi

# Get initial admin password
log_info "Getting initial admin password..."
ADMIN_PASSWORD=""

# Try to get from secret first (recommended method)
if kubectl get secret -n "${NAMESPACE}" jenkins &> /dev/null; then
    ADMIN_PASSWORD=$(kubectl get secret -n "${NAMESPACE}" jenkins -o jsonpath='{.data.jenkins-admin-password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
fi

# Fallback: Get from pod (older method)
if [ -z "${ADMIN_PASSWORD}" ]; then
    log_warn "Password not in secret, checking pod..."
    ADMIN_PASSWORD=$(kubectl exec -n "${NAMESPACE}" "${JENKINS_POD}" -- cat /run/secrets/additional/chart-admin-password 2>/dev/null || echo "")
fi

# Another fallback: Direct file in pod
if [ -z "${ADMIN_PASSWORD}" ]; then
    ADMIN_PASSWORD=$(kubectl exec -n "${NAMESPACE}" "${JENKINS_POD}" -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
fi

# Display results
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Jenkins Access Information${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Jenkins URL:${NC}"
echo "  ${FULL_JENKINS_URL}"
echo ""
echo -e "${YELLOW}Username:${NC}"
echo "  admin"
echo ""
echo -e "${YELLOW}Password:${NC}"
if [ -n "${ADMIN_PASSWORD}" ]; then
    echo "  ${ADMIN_PASSWORD}"
else
    log_error "Could not retrieve admin password"
    echo ""
    echo "Try manually with:"
    echo "  kubectl exec -n ${NAMESPACE} ${JENKINS_POD} -- cat /var/jenkins_home/secrets/initialAdminPassword"
fi
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Additional helpful commands
log_info "Helpful commands:"
echo ""
echo "  # View Jenkins logs"
echo "  kubectl logs -n ${NAMESPACE} ${JENKINS_POD} -f"
echo ""
echo "  # Access Jenkins shell"
echo "  kubectl exec -n ${NAMESPACE} -it ${JENKINS_POD} -- /bin/bash"
echo ""
echo "  # Restart Jenkins"
echo "  kubectl rollout restart deployment -n ${NAMESPACE} jenkins"
echo ""
