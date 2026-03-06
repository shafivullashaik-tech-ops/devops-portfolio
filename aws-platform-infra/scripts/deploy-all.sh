#!/bin/bash
#
# deploy-all.sh
# Complete deployment orchestration script for DevOps Portfolio
#
# This script automates the entire deployment process:
# 1. Sets up Terraform backend
# 2. Deploys AWS infrastructure (VPC, EKS, ECR)
# 3. Configures kubectl
# 4. Deploys platform services (ArgoCD, Jenkins, monitoring)
# 5. Deploys sample application
#
# Usage: ./deploy-all.sh <environment> [aws-region]
# Example: ./deploy-all.sh dev us-east-1
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}STEP: $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_banner() {
    echo ""
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        🚀 DevOps Portfolio - Complete Deployment 🚀           ║
║                                                                ║
║  AWS EKS + Jenkins + ArgoCD + Monitoring Stack                 ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

confirm_action() {
    local message=$1
    echo -e "${YELLOW}${message}${NC}"
    read -p "Continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking Prerequisites"

    local missing_tools=()

    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    fi

    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install missing tools:"
        echo "  AWS CLI:    https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
        echo "  Terraform:  https://www.terraform.io/downloads"
        echo "  kubectl:    https://kubernetes.io/docs/tasks/tools/"
        echo "  Helm:       https://helm.sh/docs/intro/install/"
        exit 1
    fi

    log_info "All required tools are installed ✓"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        log_error "Run: aws configure"
        exit 1
    fi

    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    local aws_user=$(aws sts get-caller-identity --query Arn --output text)
    log_info "AWS Account: ${aws_account}"
    log_info "AWS User: ${aws_user}"

    # Check Terraform version
    local tf_version=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    log_info "Terraform version: ${tf_version}"

    # Check kubectl version
    local kubectl_version=$(kubectl version --client --short 2>/dev/null | grep -o 'v[0-9.]*' || echo "unknown")
    log_info "kubectl version: ${kubectl_version}"
}

# Main script
main() {
    print_banner

    # Check arguments
    if [ $# -lt 1 ]; then
        log_error "Environment argument required"
        echo "Usage: $0 <environment> [aws-region]"
        echo "Example: $0 dev us-east-1"
        exit 1
    fi

    ENVIRONMENT=$1
    AWS_REGION=${2:-us-east-1}
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    TERRAFORM_DIR="${PROJECT_ROOT}/aws-platform-infra/terraform/environments/${ENVIRONMENT}"

    log_info "Environment: ${ENVIRONMENT}"
    log_info "AWS Region: ${AWS_REGION}"
    log_info "Project Root: ${PROJECT_ROOT}"
    echo ""

    # Confirm deployment
    confirm_action "⚠️  This will create AWS resources that may incur costs (~\$185/month for dev environment)"

    # Run checks
    check_prerequisites

    # Step 1: Setup Terraform Backend
    log_step "1/7: Setting up Terraform Backend"
    if [ -f "${SCRIPT_DIR}/setup-backend.sh" ]; then
        bash "${SCRIPT_DIR}/setup-backend.sh" "${ENVIRONMENT}" "${AWS_REGION}"
    else
        log_warn "setup-backend.sh not found, skipping backend setup"
    fi

    # Step 2: Deploy Infrastructure
    log_step "2/7: Deploying AWS Infrastructure (VPC, EKS, ECR)"

    if [ ! -d "${TERRAFORM_DIR}" ]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        exit 1
    fi

    cd "${TERRAFORM_DIR}"

    log_info "Initializing Terraform..."
    terraform init

    log_info "Creating Terraform plan..."
    terraform plan -out=tfplan

    confirm_action "Review the plan above. Ready to apply?"

    log_info "Applying Terraform configuration..."
    terraform apply tfplan

    log_info "Infrastructure deployment complete ✓"

    # Get outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    ECR_REPOSITORY=$(terraform output -raw ecr_repository_url)
    VPC_ID=$(terraform output -raw vpc_id)

    log_info "Cluster Name: ${CLUSTER_NAME}"
    log_info "ECR Repository: ${ECR_REPOSITORY}"
    log_info "VPC ID: ${VPC_ID}"

    # Step 3: Configure kubectl
    log_step "3/7: Configuring kubectl"

    log_info "Updating kubeconfig..."
    aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

    log_info "Verifying cluster access..."
    kubectl cluster-info
    kubectl get nodes

    log_info "kubectl configured successfully ✓"

    # Step 4: Deploy ArgoCD
    log_step "4/7: Deploying ArgoCD"

    GITOPS_DIR="${PROJECT_ROOT}/gitops-eks-platform"

    if [ -d "${GITOPS_DIR}/bootstrap" ]; then
        log_info "Creating argocd namespace..."
        kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

        log_info "Installing ArgoCD..."
        kubectl apply -k "${GITOPS_DIR}/bootstrap"

        log_info "Waiting for ArgoCD to be ready..."
        kubectl wait --for=condition=available --timeout=300s \
            deployment/argocd-server -n argocd

        log_info "ArgoCD deployed successfully ✓"

        # Get ArgoCD password
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}ArgoCD Access Information${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Username: admin"
        echo "Password: ${ARGOCD_PASSWORD}"
        echo ""
        echo "Port-forward to access:"
        echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
        echo "  https://localhost:8080"
        echo ""
    else
        log_warn "GitOps directory not found, skipping ArgoCD deployment"
    fi

    # Step 5: Deploy Jenkins
    log_step "5/7: Deploying Jenkins"

    log_info "Adding Jenkins Helm repository..."
    helm repo add jenkins https://charts.jenkins.io
    helm repo update

    log_info "Creating jenkins namespace..."
    kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

    log_info "Installing Jenkins..."
    helm upgrade --install jenkins jenkins/jenkins \
        --namespace jenkins \
        --set controller.serviceType=LoadBalancer \
        --set controller.installPlugins[0]=kubernetes:latest \
        --set controller.installPlugins[1]=workflow-aggregator:latest \
        --set controller.installPlugins[2]=git:latest \
        --set controller.installPlugins[3]=configuration-as-code:latest \
        --wait \
        --timeout 10m

    log_info "Jenkins deployed successfully ✓"

    # Get Jenkins info
    if [ -f "${SCRIPT_DIR}/get-jenkins-info.sh" ]; then
        bash "${SCRIPT_DIR}/get-jenkins-info.sh" jenkins
    fi

    # Step 6: Deploy Monitoring Stack
    log_step "6/7: Deploying Monitoring Stack (Prometheus & Grafana)"

    log_info "Adding Prometheus Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    log_info "Creating monitoring namespace..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    log_info "Installing Prometheus Stack..."
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword=admin \
        --wait \
        --timeout 10m

    log_info "Monitoring stack deployed successfully ✓"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Grafana Access Information${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Username: admin"
    echo "Password: admin"
    echo ""
    echo "Port-forward to access:"
    echo "  kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
    echo "  http://localhost:3000"
    echo ""

    # Step 7: Deploy Sample Application
    log_step "7/7: Deploying Sample Application"

    APP_CHART_DIR="${PROJECT_ROOT}/app-microservice-demo/helm"

    if [ -d "${APP_CHART_DIR}" ]; then
        log_info "Creating demo namespace..."
        kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -

        log_info "Building and pushing demo app image..."
        cd "${PROJECT_ROOT}/app-microservice-demo"

        # Build Docker image
        docker build -t demo-app:latest .

        # Tag for ECR
        docker tag demo-app:latest "${ECR_REPOSITORY}:latest"

        # Login to ECR
        aws ecr get-login-password --region "${AWS_REGION}" | \
            docker login --username AWS --password-stdin "${ECR_REPOSITORY}"

        # Push to ECR
        docker push "${ECR_REPOSITORY}:latest"

        log_info "Installing demo application..."
        helm upgrade --install demo-app "${APP_CHART_DIR}" \
            --namespace demo \
            --set image.repository="${ECR_REPOSITORY}" \
            --set image.tag=latest \
            --wait \
            --timeout 5m

        log_info "Demo application deployed successfully ✓"
    else
        log_warn "Demo app Helm chart not found, skipping application deployment"
    fi

    # Final Summary
    log_step "🎉 Deployment Complete!"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}            Deployment Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Infrastructure:${NC}"
    echo "  ✓ VPC with public/private subnets"
    echo "  ✓ EKS Cluster: ${CLUSTER_NAME}"
    echo "  ✓ ECR Repository: ${ECR_REPOSITORY}"
    echo ""
    echo -e "${YELLOW}Platform Services:${NC}"
    echo "  ✓ ArgoCD (GitOps)"
    echo "  ✓ Jenkins (CI/CD)"
    echo "  ✓ Prometheus + Grafana (Monitoring)"
    echo ""
    echo -e "${YELLOW}Applications:${NC}"
    echo "  ✓ Demo Microservice"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Access ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  2. Access Grafana: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
    echo "  3. Access Demo App: kubectl port-forward svc/demo-app -n demo 3000:3000"
    echo ""
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl get svc --all-namespaces"
    echo "  helm list --all-namespaces"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    log_info "For detailed documentation, see: ${PROJECT_ROOT}/START_HERE.md"
}

# Run main function
main "$@"
