# DevOps Portfolio - AWS EKS + Jenkins + GitOps

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/eks/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Jenkins](https://img.shields.io/badge/Jenkins-CI-D24939?logo=jenkins&logoColor=white)](https://www.jenkins.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Production-ready DevOps infrastructure demonstrating enterprise CI/CD practices with GitOps and progressive delivery.

> A comprehensive portfolio project showcasing modern DevOps practices including Infrastructure as Code, GitOps, observability, and security best practices on AWS.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Best Practices Demonstrated](#best-practices-demonstrated)
- [Technology Stack](#technology-stack)
- [Cost Optimization](#cost-optimization)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Cleanup](#cleanup)
- [License](#license)
- [Contact](#contact)

## Features

- **Infrastructure as Code**: Modular Terraform setup with reusable modules for VPC, EKS, and ECR
- **Automated CI/CD**: Jenkins pipelines with automated testing, security scanning, and image building
- **GitOps Deployment**: ArgoCD for declarative, Git-driven deployments with automatic reconciliation
- **Container Orchestration**: Production-grade EKS cluster with auto-scaling and high availability
- **Comprehensive Observability**: Prometheus, Grafana, and CloudWatch for metrics, logs, and monitoring
- **Security First**: IRSA (IAM Roles for Service Accounts), private subnets, security scanning, and least privilege policies
- **Cost Optimized**: Right-sized instances, ECR lifecycle policies, and infrastructure automation for easy teardown
- **Production Ready**: Health checks, HPA, PodDisruptionBudgets, and multi-AZ deployment

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

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **AWS CLI** | 2.x | AWS resource management | [Install Guide](https://aws.amazon.com/cli/) |
| **Terraform** | 1.5+ | Infrastructure provisioning | [Install Guide](https://www.terraform.io/downloads) |
| **kubectl** | 1.28+ | Kubernetes management | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| **Helm** | 3.x | Kubernetes package manager | [Install Guide](https://helm.sh/docs/intro/install/) |
| **Docker** | 20.x+ | Container runtime | [Install Guide](https://docs.docker.com/get-docker/) |
| **git** | 2.x+ | Version control | [Install Guide](https://git-scm.com/downloads) |

### AWS Configuration

```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity

# Ensure you have appropriate IAM permissions for:
# - VPC, EKS, ECR, IAM, S3, DynamoDB, CloudWatch
```

### AWS Account Requirements

- Active AWS account with programmatic access
- IAM user/role with administrative permissions (or specific permissions for EKS, VPC, ECR, S3, DynamoDB)
- Sufficient service limits for EKS clusters, VPCs, and EC2 instances
- Budget awareness: ~$185/month for dev environment

## Quick Start

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
- **Metrics**: Prometheus + Grafana (Golden Signals: Latency, Traffic, Errors, Saturation)
- **Logs**: CloudWatch + FluentBit (structured JSON logging, centralized aggregation)
- **Dashboards**: Grafana with pre-configured dashboards and alerts
- **Monitoring**: Application and infrastructure health checks
- Health and readiness probes for all services
- SLO tracking and alerting

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

## Documentation

Comprehensive documentation is available in the following locations:

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture diagrams, traffic flow, and component interactions
- **[docs/](docs/)** - Additional documentation including:
  - [GameDay Exercises](docs/gameday.md) - Chaos engineering and resilience testing
  - [Postmortems](docs/postmortems/) - Incident analysis and lessons learned
- **[SRE Runbooks](sre-observability-stack/runbooks/)** - Operational playbooks for common issues:
  - [High Error Rate](sre-observability-stack/runbooks/high-error-rate.md)
  - [Pod CrashLoopBackOff](sre-observability-stack/runbooks/crashloop.md)
  - [High Latency](sre-observability-stack/runbooks/high-latency.md)
- **Module-specific READMEs** - Each Terraform module and component has its own README

## Troubleshooting

### Common Issues

**1. Terraform Backend Not Initialized**
```bash
Error: Backend initialization required

Solution: Run the backend setup script first
cd aws-platform-infra/scripts
./setup-backend.sh dev us-east-1
```

**2. kubectl Cannot Connect to Cluster**
```bash
Error: The connection to the server localhost:8080 was refused

Solution: Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-dev-cluster
```

**3. ArgoCD Sync Issues**
```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# View detailed sync status
argocd app get <app-name>

# Force sync if needed
argocd app sync <app-name> --force
```

**4. ECR Authentication Errors**
```bash
# Refresh ECR login token
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

**5. Insufficient AWS Permissions**
```bash
# Verify your IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <your-username>
```

### Getting Help

- Check the [GitHub Issues](https://github.com/shafivullashaik-tech-ops/devops-portfolio/issues) for known problems
- Review the [SRE Runbooks](sre-observability-stack/runbooks/) for operational guidance
- Examine CloudWatch logs and Kubernetes events for error details

## Contributing

Contributions are welcome! This is a portfolio project, but improvements and suggestions are appreciated.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
   - Follow existing code style and conventions
   - Update documentation as needed
   - Test your changes thoroughly
4. **Commit your changes**
   ```bash
   git commit -m "feat: add your feature description"
   ```
5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```
6. **Open a Pull Request**

### Contribution Guidelines

- **Code Quality**: Ensure Terraform formatting (`terraform fmt`) and validation (`terraform validate`)
- **Documentation**: Update relevant README files and documentation
- **Security**: Never commit credentials, secrets, or sensitive information
- **Testing**: Test infrastructure changes in a dev environment first
- **Commit Messages**: Use conventional commits format (feat, fix, docs, etc.)

## Cleanup

### Destroy Infrastructure

To tear down all AWS resources and avoid ongoing costs:

```bash
# Destroy the EKS cluster and all resources
cd aws-platform-infra/terraform/environments/dev
terraform destroy

# Note: This will prompt for confirmation before destroying resources
# Review the plan carefully before confirming
```

### Cleanup Verification

```bash
# Verify EKS cluster is deleted
aws eks list-clusters --region us-east-1

# Verify VPC is deleted
aws ec2 describe-vpcs --region us-east-1

# Check for any remaining ECR images
aws ecr describe-repositories --region us-east-1
```

**Important**: Terraform destroy should remove all resources, but manually verify to avoid unexpected charges.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

**Shaik Shafivulla**

- **GitHub**: [@shafivullashaik-tech-ops](https://github.com/shafivullashaik-tech-ops)
- **LinkedIn**: [Connect with me] *linkedin.com/in/shafivulla-shaik-b4b520120
- **Email**: *shafivullashaik916@gmail.com*

---

**Project Status**: Production-ready infrastructure | Actively maintained

**Last Updated**: March 2026

If you find this project helpful, please consider giving it a star!
