# Deployment Scripts

Automation scripts for deploying and managing the infrastructure.

## Scripts

### setup-backend.sh

Creates Terraform remote backend (S3 + DynamoDB).

**Usage:**
```bash
./setup-backend.sh <environment> [aws-region]
```

**Example:**
```bash
./setup-backend.sh dev us-east-1
```

**Creates:**
- S3 Bucket: `devops-portfolio-tfstate-<environment>`
- DynamoDB Table: `devops-portfolio-tfstate-lock-<environment>`

**Features:**
- Versioning and encryption enabled
- Public access blocked
- SSL enforcement

---

### get-jenkins-info.sh

Retrieves Jenkins access information from Kubernetes cluster.

**Usage:**
```bash
./get-jenkins-info.sh [namespace]
```

**Example:**
```bash
./get-jenkins-info.sh jenkins
```

**Output:**
- Jenkins URL
- Admin credentials
- Helpful management commands

---

### deploy-all.sh

Complete end-to-end deployment orchestration.

**Usage:**
```bash
./deploy-all.sh <environment> [aws-region]
```

**Example:**
```bash
./deploy-all.sh dev us-east-1
```

**Deployment Steps:**
1. Prerequisites validation
2. Terraform backend setup
3. Infrastructure deployment (VPC, EKS, ECR)
4. kubectl configuration
5. ArgoCD installation
6. Jenkins installation
7. Monitoring stack (Prometheus + Grafana)
8. Sample application deployment

**Prerequisites:**
- AWS CLI, Terraform, kubectl, Helm, Docker
- AWS credentials configured
- Docker daemon running

---

## Quick Start

```bash
# Setup backend
./setup-backend.sh dev us-east-1

# Deploy everything
./deploy-all.sh dev us-east-1
```

## Accessing Services

**ArgoCD:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Jenkins:**
```bash
./get-jenkins-info.sh jenkins
```

**Grafana:**
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```

## Cleanup

```bash
cd ../terraform/environments/dev
terraform destroy
```
