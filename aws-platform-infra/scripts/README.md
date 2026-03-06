# Deployment Scripts

This directory contains automation scripts for deploying and managing the DevOps portfolio infrastructure.

## Scripts Overview

### 1. setup-backend.sh

Creates the Terraform remote backend infrastructure (S3 bucket + DynamoDB table).

**Purpose:**
- Creates S3 bucket for Terraform state storage
- Enables versioning and encryption on S3 bucket
- Creates DynamoDB table for state locking
- Configures security best practices (block public access, require SSL)

**Usage:**
```bash
./setup-backend.sh <environment> [aws-region]
```

**Examples:**
```bash
# Setup backend for dev environment in us-east-1
./setup-backend.sh dev us-east-1

# Setup backend for prod environment in eu-west-1
./setup-backend.sh prod eu-west-1
```

**What it creates:**
- S3 Bucket: `devops-portfolio-tfstate-<environment>`
- DynamoDB Table: `devops-portfolio-tfstate-lock-<environment>`

**Prerequisites:**
- AWS CLI installed and configured
- AWS credentials with permissions to create S3 and DynamoDB resources

---

### 2. get-jenkins-info.sh

Retrieves Jenkins access information from a running Kubernetes cluster.

**Purpose:**
- Finds Jenkins pod in specified namespace
- Retrieves Jenkins URL (LoadBalancer or port-forward instructions)
- Extracts initial admin password from secrets
- Displays helpful commands for managing Jenkins

**Usage:**
```bash
./get-jenkins-info.sh [namespace]
```

**Examples:**
```bash
# Get Jenkins info from default 'jenkins' namespace
./get-jenkins-info.sh

# Get Jenkins info from custom namespace
./get-jenkins-info.sh ci-cd
```

**Output includes:**
- Jenkins URL
- Admin username
- Initial admin password
- Helpful kubectl commands for logs, shell access, and restarts

**Prerequisites:**
- kubectl installed and configured
- kubectl context set to target cluster
- Jenkins deployed in cluster

---

### 3. deploy-all.sh

Complete end-to-end deployment orchestration script.

**Purpose:**
- Automates the entire portfolio deployment
- Validates prerequisites
- Executes deployment steps in correct order
- Provides progress feedback and error handling
- Displays access information for all services

**Usage:**
```bash
./deploy-all.sh <environment> [aws-region]
```

**Examples:**
```bash
# Deploy dev environment to us-east-1
./deploy-all.sh dev us-east-1

# Deploy prod environment to eu-west-1
./deploy-all.sh prod eu-west-1
```

**Deployment Steps:**

1. **Prerequisites Check**
   - Verifies AWS CLI, Terraform, kubectl, helm are installed
   - Validates AWS credentials
   - Displays AWS account and tool versions

2. **Terraform Backend Setup**
   - Calls setup-backend.sh
   - Creates S3 bucket and DynamoDB table

3. **Infrastructure Deployment**
   - Runs Terraform init/plan/apply
   - Creates VPC, EKS cluster, ECR repository
   - Displays Terraform outputs

4. **kubectl Configuration**
   - Updates kubeconfig for EKS cluster
   - Verifies cluster connectivity

5. **ArgoCD Deployment**
   - Creates argocd namespace
   - Installs ArgoCD via Kustomize
   - Retrieves initial admin password

6. **Jenkins Deployment**
   - Adds Jenkins Helm repository
   - Installs Jenkins via Helm
   - Calls get-jenkins-info.sh for access details

7. **Monitoring Stack Deployment**
   - Installs Prometheus + Grafana stack
   - Configures default admin credentials

8. **Sample Application Deployment**
   - Builds demo-app Docker image
   - Pushes image to ECR
   - Deploys via Helm chart

**Prerequisites:**
- All tools: aws, terraform, kubectl, helm, docker
- AWS credentials configured
- Docker daemon running

**Cost Warning:**
The script displays a warning before deployment:
```
⚠️  This will create AWS resources that may incur costs (~$185/month for dev environment)
```

User must confirm before proceeding.

---

## Quick Start

### First-Time Deployment

```bash
# 1. Setup backend (one-time per environment)
./setup-backend.sh dev us-east-1

# 2. Deploy everything
./deploy-all.sh dev us-east-1
```

### Accessing Services

After deployment completes:

**ArgoCD:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Username: admin
# Password: (displayed in deploy-all.sh output)
```

**Jenkins:**
```bash
# Get access info
./get-jenkins-info.sh jenkins

# Or port-forward if not using LoadBalancer
kubectl port-forward svc/jenkins -n jenkins 8080:8080
# Open: http://localhost:8080
```

**Grafana:**
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# Open: http://localhost:3000
# Username: admin
# Password: admin
```

**Demo Application:**
```bash
kubectl port-forward svc/demo-app -n demo 3000:3000
# Open: http://localhost:3000
```

---

## Error Handling

### Backend Setup Failures

**Problem:** S3 bucket creation fails with "BucketAlreadyExists"
**Solution:** Bucket name is globally unique. The script uses `devops-portfolio-tfstate-<env>`. If taken, modify BUCKET_NAME variable.

**Problem:** DynamoDB creation fails with permissions error
**Solution:** Ensure AWS user has `dynamodb:CreateTable` permission.

### Deployment Failures

**Problem:** Terraform apply fails with "InvalidParameterException"
**Solution:** Check AWS quota limits (EKS clusters, VPCs, EIPs). Request limit increases if needed.

**Problem:** kubectl commands fail after EKS creation
**Solution:** Run manually: `aws eks update-kubeconfig --name <cluster-name> --region <region>`

**Problem:** Helm install times out
**Solution:** Check pod status: `kubectl get pods -n <namespace>`. View logs: `kubectl logs <pod-name> -n <namespace>`

### Jenkins Access Issues

**Problem:** get-jenkins-info.sh shows "Jenkins pod not found"
**Solution:** Check if Jenkins is deployed: `kubectl get pods -n jenkins`

**Problem:** Cannot retrieve admin password
**Solution:** Manually retrieve: `kubectl exec -n jenkins <jenkins-pod> -- cat /var/jenkins_home/secrets/initialAdminPassword`

---

## Script Features

### Colorized Output
All scripts use colored output for better readability:
- 🟢 Green: Success/Info messages
- 🟡 Yellow: Warnings
- 🔴 Red: Errors
- 🔵 Blue: Section headers

### Safety Features
- **Prerequisites checking**: Validates required tools before proceeding
- **Confirmation prompts**: Asks for confirmation before expensive operations
- **Error handling**: Uses `set -euo pipefail` for fail-fast behavior
- **Idempotency**: Scripts can be run multiple times safely

### Progress Tracking
- Clear step indicators (1/7, 2/7, etc.)
- Visual separators for different phases
- Summary output at completion
- Access credentials displayed clearly

---

## Customization

### Environment Variables

Scripts respect these environment variables:

```bash
# Override default AWS region
export AWS_REGION=eu-west-1

# Use custom AWS profile
export AWS_PROFILE=devops-portfolio

# Terraform workspace
export TF_WORKSPACE=dev
```

### Modifying Deployment

To customize what gets deployed, edit `deploy-all.sh`:

**Skip ArgoCD:**
```bash
# Comment out Step 4 in deploy-all.sh
# log_step "4/7: Deploying ArgoCD"
```

**Use different Helm values:**
```bash
# Modify helm install commands
helm upgrade --install jenkins jenkins/jenkins \
    --namespace jenkins \
    --values custom-values.yaml
```

**Add additional services:**
```bash
# Add new step before final summary
log_step "8/8: Deploying Custom Service"
# Your deployment commands here
```

---

## Troubleshooting Commands

```bash
# Check all pod status
kubectl get pods --all-namespaces

# View pod logs
kubectl logs <pod-name> -n <namespace> -f

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Check service endpoints
kubectl get svc --all-namespaces

# View Helm releases
helm list --all-namespaces

# Check Terraform state
cd ../terraform/environments/dev
terraform show

# View cluster info
kubectl cluster-info
kubectl get nodes
```

---

## Cleanup

To destroy all resources:

```bash
# 1. Delete Helm releases
helm uninstall demo-app -n demo
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall jenkins -n jenkins

# 2. Delete ArgoCD
kubectl delete -k ../../gitops-eks-platform/bootstrap

# 3. Destroy infrastructure
cd ../terraform/environments/dev
terraform destroy

# 4. (Optional) Delete backend resources
aws s3 rm s3://devops-portfolio-tfstate-dev --recursive
aws s3 rb s3://devops-portfolio-tfstate-dev
aws dynamodb delete-table --table-name devops-portfolio-tfstate-lock-dev
```

---

## Interview Talking Points

When demonstrating these scripts in interviews:

### "Walk me through your deployment automation"

**Answer:** "I've created three main scripts that handle the complete deployment lifecycle:

1. **setup-backend.sh** - Sets up Terraform remote state infrastructure with S3 and DynamoDB, implementing security best practices like encryption at rest, versioning, and SSL enforcement.

2. **get-jenkins-info.sh** - Utility script that retrieves Jenkins access credentials from Kubernetes secrets, demonstrating knowledge of Kubernetes secret management and kubectl automation.

3. **deploy-all.sh** - Complete orchestration script that:
   - Validates prerequisites (AWS CLI, Terraform, kubectl, helm)
   - Deploys infrastructure via Terraform
   - Configures kubectl for EKS access
   - Installs platform services (ArgoCD, Jenkins, monitoring)
   - Builds and deploys sample application
   - Provides clear access information for all services

The scripts are idempotent, include error handling, and provide colorized output for better UX. They demonstrate infrastructure-as-code principles and DevOps automation best practices."

### "How do you handle failures in automated deployments?"

**Answer:** "Multiple layers:

1. **Fail-fast**: All scripts use `set -euo pipefail` to exit immediately on errors
2. **Prerequisites checking**: Validate tools and credentials before starting
3. **Confirmation prompts**: Ask user to review Terraform plan before applying
4. **Clear error messages**: Scripts output specific error messages with remediation steps
5. **Terraform state locking**: DynamoDB prevents concurrent modifications
6. **Helm --wait flag**: Ensures deployments succeed before proceeding
7. **Kubectl wait commands**: Verify pods are ready before moving to next step

For partial failures, the scripts are idempotent - you can re-run them safely to continue from where they failed."

---

## Additional Resources

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Jenkins on Kubernetes](https://www.jenkins.io/doc/book/installing/kubernetes/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
