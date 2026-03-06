# DevOps Portfolio - AWS EKS + Jenkins + GitOps

Production-ready DevOps infrastructure demonstrating enterprise CI/CD practices with GitOps and progressive delivery.

## Architecture

```
Developer → GitHub → Jenkins (CI) → ECR → GitOps Repo → ArgoCD (CD) → EKS → Monitoring
```

### Components

- **Infrastructure**: AWS (VPC, EKS, ECR) managed with Terraform
- **CI**: Jenkins with automated build, test, and security scanning
- **CD**: GitOps with ArgoCD for declarative deployments
- **Orchestration**: Amazon EKS (Kubernetes)
- **Observability**: Prometheus + Grafana + CloudWatch
- **Security**: IRSA (IAM Roles for Service Accounts)

## Repository Structure

### 1. `terraform-aws-modules/` - Terraform Modules
Reusable infrastructure modules:
- VPC with public/private subnets across multiple AZs
- EKS cluster with IRSA enabled
- ECR repositories with lifecycle policies

### 2. `aws-platform-infra/` - Infrastructure Deployment
Terraform configurations consuming the modules:
- Environment-specific configurations (dev/prod)
- Backend configuration for remote state
- Deployment automation scripts

### 3. `gitops-eks-platform/` - GitOps Configuration
ArgoCD applications and platform services:
- ArgoCD bootstrap with app-of-apps pattern
- Environment-specific configurations
- Platform services (monitoring, ingress)

### 4. `app-microservice-demo/` - Sample Application
Demo microservice with complete CI/CD:
- Node.js/Express API
- Dockerfile with multi-stage builds
- Jenkinsfile (declarative pipeline)
- Helm chart for Kubernetes deployment
- Unit and integration tests

## Quick Start

### Prerequisites
- AWS CLI configured
- Tools: terraform, kubectl, helm, docker

### Deployment

```bash
# 1. Setup Terraform backend
cd aws-platform-infra/scripts
./setup-backend.sh dev us-east-1

# 2. Deploy all infrastructure and services
./deploy-all.sh dev us-east-1
```

### Access Services

```bash
# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# Demo Application
kubectl port-forward svc/demo-app -n demo 3000:3000
```

## Best Practices Demonstrated

### Infrastructure as Code
- Modular Terraform design for reusability
- Remote state with S3 and DynamoDB locking
- Environment-specific configurations
- Immutable infrastructure

### Security
- IRSA for secure AWS authentication (no hardcoded credentials)
- Private subnets for application workloads
- Security scanning (Trivy for images, npm audit for dependencies)
- Least privilege IAM policies
- Network policies and security groups

### CI/CD
- Declarative Jenkins pipelines
- Parallel test and scan execution
- Immutable artifacts with semantic versioning
- GitOps for deployment (separation of CI and CD)
- Automated deployments with manual approval gates

### Kubernetes
- Multi-stage Docker builds for optimized images
- Health checks (liveness/readiness probes)
- Resource requests and limits
- Horizontal Pod Autoscaling
- PodDisruptionBudgets for high availability

### Observability
- Prometheus metrics exposure
- Structured JSON logging
- Grafana dashboards
- Health and readiness endpoints
- Application performance monitoring

### GitOps
- Git as single source of truth
- Declarative configuration
- ArgoCD for continuous reconciliation
- Environment promotion workflow
- Easy rollback via Git revert

## Technology Stack

**Cloud**: AWS (VPC, EKS, ECR, IAM, CloudWatch)
**IaC**: Terraform
**CI**: Jenkins
**CD**: ArgoCD
**Container Orchestration**: Kubernetes (EKS)
**Monitoring**: Prometheus, Grafana
**Container Registry**: AWS ECR
**Languages**: Node.js, JavaScript, Bash
**Tools**: Docker, Helm, kubectl

## Cost Optimization

Development environment: ~$185/month
- EKS Control Plane: $72
- EC2 Nodes (2x t3.medium): $60
- NAT Gateway: $32
- Other services: ~$21

Optimizations implemented:
- Single NAT Gateway for dev
- Right-sized instance types
- ECR lifecycle policies
- Infrastructure can be torn down when not in use

## Cleanup

```bash
cd aws-platform-infra/terraform/environments/dev
terraform destroy
```

---

**Author**: Shaik Shafivulla
**Status**: Production-ready infrastructure
