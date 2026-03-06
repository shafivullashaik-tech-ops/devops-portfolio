# Quick Start Guide - Portfolio Setup

This guide gets your portfolio up and running in **30 minutes** for demos and interviews.

## 📋 Pre-requisites Checklist

Before starting, ensure you have:

- [ ] AWS Account (Free tier eligible)
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.5.0 installed
- [ ] kubectl installed
- [ ] Helm installed
- [ ] Git installed
- [ ] SSH key pair created in AWS EC2 (for Jenkins)

## ⚡ Fast Track Deployment

### Step 1: Setup AWS Credentials (5 min)

```bash
# Configure AWS CLI
aws configure
# AWS Access Key ID: [Enter your key]
# AWS Secret Access Key: [Enter your secret]
# Default region: us-east-1
# Default output format: json

# Verify connection
aws sts get-caller-identity

# Create EC2 key pair for Jenkins
aws ec2 create-key-pair \
  --key-name portfolio-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/portfolio-key.pem

chmod 400 ~/.ssh/portfolio-key.pem
```

### Step 2: Initialize Terraform Backend (5 min)

```bash
cd /mnt/c/Users/shaik.shafivulla/Documents/portfolio/aws-platform-infra/terraform/shared/backend-setup

# Create S3 bucket for Terraform state
./create-backend.sh

# This creates:
# - S3 bucket: portfolio-terraform-state-<your-account-id>
# - DynamoDB table: portfolio-terraform-locks
```

### Step 3: Deploy Infrastructure (20 min)

```bash
cd /mnt/c/Users/shaik.shafivulla/Documents/portfolio/aws-platform-infra/terraform/environments/dev

# Review variables
cat terraform.tfvars

# Initialize Terraform
terraform init

# Plan (review what will be created)
terraform plan -out=tfplan

# Apply (this takes ~20 minutes, mostly EKS cluster creation)
terraform apply tfplan

# Save outputs
terraform output > ../../outputs.txt
```

**What gets created:**
- VPC with public/private subnets across 2 AZs
- EKS cluster with 2 t3.medium worker nodes
- ECR repository for Docker images
- Jenkins EC2 instance (t3.small)
- IAM roles with IRSA for secure pod authentication
- All networking (NAT Gateway, Internet Gateway, Route Tables)

### Step 4: Configure kubectl (2 min)

```bash
# Get kubeconfig for EKS
aws eks update-kubeconfig --name portfolio-eks-dev --region us-east-1

# Verify connection
kubectl get nodes
# Should show 2 nodes in Ready state

# Check EKS add-ons
kubectl get pods -A
```

### Step 5: Access Jenkins (3 min)

```bash
# Get Jenkins URL from Terraform output
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
echo "Jenkins URL: http://${JENKINS_IP}:8080"

# Get initial admin password
ssh -i ~/.ssh/portfolio-key.pem ec2-user@${JENKINS_IP} \
  "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"

# Or use helper script
cd ../../../scripts
./get-jenkins-info.sh
```

**Jenkins Setup:**
1. Open browser to Jenkins URL
2. Enter initial admin password
3. Click "Install suggested plugins"
4. Create admin user
5. Install additional plugins:
   - Docker Pipeline
   - Kubernetes
   - AWS Steps
   - GitHub

### Step 6: Deploy ArgoCD (5 min)

```bash
cd /mnt/c/Users/shaik.shafivulla/Documents/portfolio/gitops-eks-platform

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d ; echo

# Port-forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Step 7: Deploy Sample Application (5 min)

```bash
cd /mnt/c/Users/shaik.shafivulla/Documents/portfolio/app-microservice-demo

# Build Docker image locally (or wait for Jenkins)
docker build -t demo-app:v1.0.0 .

# Tag for ECR
ECR_URL=$(aws ecr describe-repositories --repository-names demo-app --query 'repositories[0].repositoryUri' --output text)
docker tag demo-app:v1.0.0 ${ECR_URL}:v1.0.0

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_URL}

# Push to ECR
docker push ${ECR_URL}:v1.0.0

# Deploy with Helm
cd helm
helm install demo-app . --namespace default \
  --set image.repository=${ECR_URL} \
  --set image.tag=v1.0.0

# Wait for deployment
kubectl wait --for=condition=available deployment/demo-app --timeout=300s

# Get service URL
kubectl get svc demo-app
```

## ✅ Verification Steps

### Check All Components

```bash
# 1. Check EKS cluster
kubectl get nodes
kubectl get pods -A

# 2. Check ArgoCD
kubectl get pods -n argocd

# 3. Check application
kubectl get pods
kubectl get svc

# 4. Test application
kubectl port-forward svc/demo-app 3000:3000
curl http://localhost:3000/health
# Should return: {"status":"healthy"}

# 5. Check Jenkins
curl http://${JENKINS_IP}:8080
# Should return Jenkins HTML
```

## 🎤 Demo Walkthrough (For Interviews)

### 1. Architecture Overview (2 min)
```bash
# Show architecture diagram
cat /mnt/c/Users/shaik.shafivulla/Documents/portfolio/ARCHITECTURE.md

# Explain:
# - Separation of CI (Jenkins) and CD (ArgoCD)
# - GitOps workflow
# - Multi-repo structure
# - Reusable Terraform modules
```

### 2. Infrastructure as Code (3 min)
```bash
cd /mnt/c/Users/shaik.shafivulla/Documents/portfolio

# Show module structure
tree terraform-aws-modules/ -L 2

# Show how platform repo consumes modules
cat aws-platform-infra/terraform/environments/dev/main.tf

# Key point: "No direct resources in platform repo, only module calls"
```

### 3. CI Pipeline (3 min)
```bash
# Show Jenkinsfile
cat app-microservice-demo/Jenkinsfile

# Explain stages:
# 1. Checkout
# 2. Build Docker image
# 3. Run tests
# 4. Security scan (Trivy)
# 5. Push to ECR
# 6. Update GitOps repo

# Key point: "Jenkins uses IRSA, no hardcoded AWS keys"
```

### 4. GitOps & CD (3 min)
```bash
# Show GitOps structure
tree gitops-eks-platform/ -L 3

# Show app-of-apps pattern
cat gitops-eks-platform/apps/app-of-apps.yaml

# Explain:
# - Git is source of truth
# - ArgoCD auto-syncs
# - Environment-specific configs
# - Easy rollbacks (git revert)
```

### 5. Live Demo - Make a Change (5 min)
```bash
cd app-microservice-demo

# Make a code change
echo "// New feature" >> src/app.js

# Commit and push
git add .
git commit -m "Add new feature"
git push

# Show Jenkins build in browser
# Show ArgoCD sync in browser
# Show new pods rolling out
kubectl get pods -w

# Show application is updated
curl http://localhost:3000/version
```

### 6. Observability (2 min)
```bash
# Show Prometheus metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090

# Show Grafana dashboards
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open: http://localhost:3000

# Show application metrics
curl http://localhost:3000/metrics
```

## 💰 Cost Management

### Daily Costs (Running 24/7)
- EKS Control Plane: $2.40/day
- EC2 Nodes (2x t3.medium): $2.00/day
- Jenkins (t3.small): $0.50/day
- NAT Gateway: $1.07/day
- **Total: ~$6/day** or **~$185/month**

### Cost Optimization for Demos

```bash
# Option 1: Stop Jenkins when not needed
aws ec2 stop-instances --instance-ids $(terraform output -raw jenkins_instance_id)
# Saves: ~$0.50/day

# Option 2: Scale down EKS nodes
kubectl scale deployment --all --replicas=0
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name portfolio-eks-dev-node-group \
  --desired-capacity 1
# Saves: ~$1/day

# Option 3: Delete everything, rebuild when needed
terraform destroy
# Saves: ~$6/day
# Rebuild takes: ~25 minutes
```

### Budget Alert Setup
```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json

# This sends email alert at 80% of monthly budget
```

## 🔥 Troubleshooting

### Issue: EKS nodes not ready
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check IAM role
aws iam get-role --role-name portfolio-eks-node-role

# Fix: Wait 5-10 minutes, nodes take time to initialize
```

### Issue: Can't access Jenkins
```bash
# Check security group
aws ec2 describe-security-groups --group-ids $(terraform output -raw jenkins_security_group_id)

# Check instance status
aws ec2 describe-instances --instance-ids $(terraform output -raw jenkins_instance_id)

# Fix: Ensure your IP is allowed in security group
# Or add 0.0.0.0/0 for testing (not recommended for production!)
```

### Issue: ArgoCD not syncing
```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Fix: Ensure GitOps repo is accessible and credentials are configured
```

### Issue: Out of budget
```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Delete everything
cd aws-platform-infra/terraform/environments/dev
terraform destroy -auto-approve
```

## 📚 Next Steps

1. **Customize Application**: Replace demo app with your own project
2. **Add Monitoring**: Deploy full Prometheus + Grafana stack
3. **Implement Canary**: Add Argo Rollouts for progressive delivery
4. **Security Scanning**: Integrate SonarQube, Snyk, or Aqua Security
5. **Multi-Environment**: Add staging and prod environments
6. **Documentation**: Create diagrams and decision logs

## 🎯 Interview Preparation

### Questions You'll Be Asked

**Q: Walk me through your CI/CD pipeline**
A: "I use a GitOps approach with Jenkins for CI and ArgoCD for CD. When code is pushed, Jenkins builds the Docker image, runs tests, scans for vulnerabilities, pushes to ECR, and updates the GitOps repo. ArgoCD detects the change and automatically syncs to the cluster. This separation of concerns provides better security and auditability."

**Q: How do you handle secrets?**
A: "I use multiple layers: AWS Secrets Manager for secret storage, External Secrets Operator to sync them to Kubernetes Secrets, and IRSA for pod-level AWS authentication. No secrets are hardcoded or stored in Git."

**Q: How do you ensure high availability?**
A: "Multi-AZ deployment, multiple NAT Gateways in prod, EKS managed node groups with autoscaling, health checks, readiness probes, and canary deployments with automatic rollback."

**Q: What about cost optimization?**
A: "Single NAT Gateway for dev, spot instances for non-critical workloads, cluster autoscaler to scale down idle nodes, lifecycle policies for ECR, and monitoring with budget alerts."

**Q: How do you handle different environments?**
A: "Kustomize overlays in the GitOps repo. Each environment has its own values.yaml with different replica counts, resource limits, and feature flags, but shares the same base manifests."

---

**Estimated Setup Time**: 30-40 minutes
**Monthly Cost**: $100-185 (can be reduced or destroyed when not in use)
**Rebuild Time**: 25 minutes (infrastructure) + 5 minutes (applications)

Ready to impress interviewers! 🚀
