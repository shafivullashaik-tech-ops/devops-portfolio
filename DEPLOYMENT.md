# 🚀 Deployment Guide — Step by Step

This guide walks you through deploying the complete DevOps portfolio infrastructure from scratch:
**AWS EKS cluster → ArgoCD → Jenkins → Prometheus + Grafana**

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Configure AWS](#2-configure-aws)
3. [Setup Terraform Backend](#3-setup-terraform-backend)
4. [Deploy AWS Infrastructure (Terraform)](#4-deploy-aws-infrastructure-terraform)
5. [Connect kubectl to EKS](#5-connect-kubectl-to-eks)
6. [Deploy ArgoCD](#6-deploy-argocd)
7. [Deploy Monitoring Stack (Prometheus + Grafana)](#7-deploy-monitoring-stack-prometheus--grafana)
8. [Deploy Jenkins](#8-deploy-jenkins)
9. [Access All Services](#9-access-all-services)
10. [Destroy Everything (Save Costs)](#10-destroy-everything-save-costs)

---

## 1. Prerequisites

Install these tools before starting:

| Tool | Min Version | Install Link |
|------|------------|--------------|
| AWS CLI | 2.x | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Terraform | 1.5+ | https://www.terraform.io/downloads |
| kubectl | 1.28+ | https://kubernetes.io/docs/tasks/tools/ |
| Helm | 3.x | https://helm.sh/docs/intro/install/ |

**Verify all tools are installed:**
```bash
aws --version
terraform --version
kubectl version --client
helm version
```

---

## 2. Configure AWS

### Set up AWS CLI profile

This project uses the **`shafi`** AWS profile. Configure it with your credentials:

```bash
aws configure --profile shafi
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-west-2`
- Default output format: `json`

**Verify it works:**
```bash
aws sts get-caller-identity --profile shafi
```

You should see your AWS Account ID, UserID, and ARN.

---

## 3. Setup Terraform Backend

Before running Terraform, you need an S3 bucket (for state storage) and DynamoDB table (for state locking).

```bash
cd aws-platform-infra/scripts
chmod +x setup-backend.sh
./setup-backend.sh dev us-west-2
```

This creates:
- ✅ S3 bucket: `devops-portfolio-tfstate-dev` (with versioning + encryption)
- ✅ DynamoDB table: `devops-portfolio-tfstate-lock-dev`

> **Note:** If you get "bucket already exists" — that's fine, it was already created before.

---

## 4. Deploy AWS Infrastructure (Terraform)

This deploys:
- **VPC** with public/private subnets across 2 AZs
- **EKS cluster** (`portfolio-eks-dev`) with 2x t3.medium nodes
- **ECR repositories** for your Docker images
- **IAM IRSA roles** for Jenkins and EBS CSI driver

```bash
# Navigate to dev environment
cd aws-platform-infra/terraform/environments/dev

# Initialize Terraform (downloads providers + configures backend)
terraform init

# Preview what will be created
terraform plan

# Deploy (takes ~15-20 minutes)
terraform apply
```

When prompted `Do you want to perform these actions?` → type **`yes`**

**After apply completes, save these outputs — you'll need them:**
```bash
terraform output cluster_name        # → portfolio-eks-dev
terraform output jenkins_irsa_role_arn
terraform output ecr_repository_url
```

> ⏱️ **Expected time:** 15–20 minutes

---

## 5. Connect kubectl to EKS

After Terraform finishes, configure kubectl to talk to your new EKS cluster:

```bash
aws eks update-kubeconfig \
  --name portfolio-eks-dev \
  --region us-west-2 \
  --profile shafi
```

**Verify connection:**
```bash
kubectl cluster-info
kubectl get nodes
```

You should see 2 nodes in `Ready` state:
```
NAME                                       STATUS   ROLES    AGE
ip-10-0-x-x.us-west-2.compute.internal   Ready    <none>   5m
ip-10-0-x-x.us-west-2.compute.internal   Ready    <none>   5m
```

---

## 6. Deploy ArgoCD

ArgoCD is the GitOps engine — it watches your Git repo and automatically deploys changes to Kubernetes.

```bash
# Step 1: Create argocd namespace
kubectl create namespace argocd

# Step 2: Install ArgoCD
kubectl apply -k gitops-eks-platform/bootstrap/ --server-side

# Step 3: Wait for ArgoCD to start (2-3 minutes)
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Step 4: Get the auto-generated admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

> 📝 **Save the password** — you'll need it to log in to the UI.

**Deploy the App-of-Apps (manages all platform services):**
```bash
kubectl apply -f gitops-eks-platform/apps/app-of-apps.yaml
```

**Access ArgoCD UI:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
→ Open: **https://localhost:8080**
- Username: `admin`
- Password: *(the one you saved above)*

> ⏱️ **Expected time:** 3–5 minutes

---

## 7. Deploy Monitoring Stack (Prometheus + Grafana)

> ⚠️ **Deploy monitoring BEFORE Jenkins** — Jenkins needs Prometheus CRDs to exist first.

```bash
# Step 1: Create monitoring namespace
kubectl create namespace monitoring

# Step 2: Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Step 3: Install Prometheus + Grafana stack
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword="Admin@1234!" \
  --set grafana.persistence.enabled=false \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp2 \
  --wait \
  --timeout 20m
```

**Access Grafana UI:**
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```
→ Open: **http://localhost:3000**
- Username: `admin`
- Password: `Admin@1234!`

> ⏱️ **Expected time:** 5–10 minutes

---

## 8. Deploy Jenkins

Jenkins is the CI engine — it builds Docker images, runs tests, and updates the GitOps repo.

### Step 8a: Get Jenkins IRSA Role ARN

```bash
cd aws-platform-infra/terraform/environments/dev
terraform output jenkins_irsa_role_arn
```

Copy the output (looks like: `arn:aws:iam::050451393596:role/portfolio-eks-dev-jenkins-irsa`)

### Step 8b: Update jenkins-values.yaml with your IRSA ARN

Open `aws-platform-infra/jenkins/jenkins-values.yaml` and find this line:
```yaml
eks.amazonaws.com/role-arn: "arn:aws:iam::050451393596:role/portfolio-eks-dev-jenkins-irsa"
```
Replace it with your actual IRSA ARN from Step 8a.

### Step 8c: Install Jenkins via Helm

```bash
# Create jenkins namespace
kubectl create namespace jenkins

# Add Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins (takes 5-10 minutes)
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values aws-platform-infra/jenkins/jenkins-values.yaml \
  --wait \
  --timeout 15m
```

### Step 8d: Get Jenkins admin password

```bash
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password
```

**Access Jenkins UI:**
```bash
kubectl port-forward svc/jenkins -n jenkins 8090:8080
```
→ Open: **http://localhost:8090**
- Username: `admin`
- Password: *(from command above)*

> ⏱️ **Expected time:** 5–10 minutes

---

## 9. Access All Services

Once everything is deployed, use these commands to access each service:

### Open 3 separate terminal windows and run:

**Terminal 1 — ArgoCD:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# → https://localhost:8080  (admin / <argocd-password>)
```

**Terminal 2 — Grafana:**
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# → http://localhost:3000  (admin / Admin@1234!)
```

**Terminal 3 — Jenkins:**
```bash
kubectl port-forward svc/jenkins -n jenkins 8090:8080
# → http://localhost:8090  (admin / <jenkins-password>)
```

### Quick Status Check

```bash
# See all running pods across all namespaces
kubectl get pods --all-namespaces

# See all services
kubectl get svc --all-namespaces

# See all Helm releases
helm list --all-namespaces
```

Expected output — all pods should show `Running` or `Completed`:
```
NAMESPACE    NAME                          READY   STATUS    
argocd       argocd-server-xxx             1/1     Running   
argocd       argocd-application-controller 1/1     Running   
jenkins      jenkins-0                     2/2     Running   
monitoring   kube-prometheus-stack-xxx     1/1     Running   
monitoring   kube-prometheus-stack-grafana 1/1     Running   
```

---

## 🔄 One-Command Deployment (Alternative)

If you want to run everything automatically after `terraform apply`, use the post-apply script:

```bash
cd aws-platform-infra/scripts
chmod +x post-apply-deploy.sh
./post-apply-deploy.sh us-west-2
```

This script does Steps 5–8 automatically in the correct order.

---

## 10. Destroy Everything (Save Costs)

> ⚠️ Do this when you're done to avoid AWS charges (~$185/month)

```bash
# Step 1: Delete Helm releases first
helm uninstall jenkins -n jenkins
helm uninstall kube-prometheus-stack -n monitoring

# Step 2: Delete ArgoCD
kubectl delete -k gitops-eks-platform/bootstrap/

# Step 3: Destroy all AWS infrastructure
cd aws-platform-infra/terraform/environments/dev
terraform destroy
```

When prompted → type **`yes`**

**Verify everything is deleted:**
```bash
aws eks list-clusters --region us-west-2 --profile shafi
aws ec2 describe-vpcs --region us-west-2 --profile shafi --query 'Vpcs[?Tags[?Key==`Project` && Value==`portfolio`]]'
```

---

## 🔧 Troubleshooting

### EKS nodes not connecting?
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check if kubeconfig is correct
kubectl config current-context
```

### ArgoCD not syncing?
```bash
# Check ArgoCD app status
kubectl get applications -n argocd

# Describe a specific app
kubectl describe application <app-name> -n argocd
```

### Jenkins pod stuck in Pending?
```bash
# Check events
kubectl describe pod jenkins-0 -n jenkins

# Most likely cause: PVC not binding (storage class issue)
kubectl get pvc -n jenkins
```

### Terraform errors?
```bash
# Re-initialize if provider issues
terraform init -upgrade

# Check AWS credentials
aws sts get-caller-identity --profile shafi
```

---

## 📊 Cost Summary (Dev Environment)

| Resource | Cost/month |
|----------|-----------|
| EKS Control Plane | ~$72 |
| EC2 Nodes (2x t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| Other (EBS, ECR, logs) | ~$21 |
| **Total** | **~$185** |

> 💡 Run `terraform destroy` when not using the cluster to save costs.

---

*Last updated: March 2026*
