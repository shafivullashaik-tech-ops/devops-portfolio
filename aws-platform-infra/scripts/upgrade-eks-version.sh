#!/bin/bash
#
# upgrade-eks-version.sh
# Upgrades EKS cluster one minor version at a time
# AWS requires: 1.28 -> 1.29 -> 1.30 -> 1.31 (cannot skip versions)
#
# Usage: ./upgrade-eks-version.sh
#

set -euo pipefail

CLUSTER_NAME="portfolio-eks-dev"
REGION="us-west-2"
PROFILE="shafi"
TARGET_VERSION="1.31"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_step()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}▶  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

wait_for_cluster() {
    local version=$1
    log_info "Waiting for cluster to become ACTIVE at version ${version} (~8-10 min)..."
    while true; do
        STATUS=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
            --region "${REGION}" --profile "${PROFILE}" \
            --query "cluster.status" --output text 2>/dev/null)
        CURRENT=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
            --region "${REGION}" --profile "${PROFILE}" \
            --query "cluster.version" --output text 2>/dev/null)
        echo -e "  Status: ${YELLOW}${STATUS}${NC} | Version: ${YELLOW}${CURRENT}${NC}"
        if [ "${STATUS}" = "ACTIVE" ] && [ "${CURRENT}" = "${version}" ]; then
            log_info "✅ Cluster is ACTIVE at version ${version}!"
            break
        fi
        sleep 30
    done
}

upgrade_to() {
    local version=$1
    CURRENT=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
        --region "${REGION}" --profile "${PROFILE}" \
        --query "cluster.version" --output text 2>/dev/null)

    if [ "${CURRENT}" = "${version}" ]; then
        log_info "Cluster already at ${version}, skipping..."
        return
    fi

    log_step "Upgrading EKS ${CURRENT} → ${version}"
    aws eks update-cluster-version \
        --name "${CLUSTER_NAME}" \
        --kubernetes-version "${version}" \
        --region "${REGION}" \
        --profile "${PROFILE}" \
        --query "update.{id:id,status:status}" \
        --output table 2>&1

    wait_for_cluster "${version}"
}

# ─── Main ───────────────────────────────────────────────────────────────────
log_step "EKS Stepwise Upgrade to ${TARGET_VERSION}"

CURRENT=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
    --region "${REGION}" --profile "${PROFILE}" \
    --query "cluster.version" --output text 2>/dev/null)
log_info "Current version: ${CURRENT}"

case "${CURRENT}" in
    "1.28") upgrade_to "1.29" ;&
    "1.29") upgrade_to "1.30" ;&
    "1.30") upgrade_to "1.31" ;&
    "1.31") log_info "✅ Cluster is already at target version 1.31!" ;;
    *)      echo "Unknown version: ${CURRENT}" ; exit 1 ;;
esac

log_step "✅ EKS upgrade complete! Now run terraform apply"
echo ""
echo "cd aws-platform-infra/terraform/environments/dev"
echo "terraform apply -auto-approve"
echo ""
