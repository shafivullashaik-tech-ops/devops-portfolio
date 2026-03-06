# DevOps Portfolio - Enterprise-Grade AWS + Jenkins + GitOps

## 🎯 Overview

This portfolio demonstrates a production-ready DevOps pipeline using industry-standard tools and practices. It showcases end-to-end automation from code commit to production deployment with observability and progressive delivery.

## 🏗️ Architecture

```
Developer → GitHub → Jenkins (CI) → ECR → GitOps Repo → ArgoCD (CD) → EKS → Monitoring
                ↓                                          ↓
            Build/Test/Scan                         Auto-sync/Rollback
```

### Key Components

- **Infrastructure**: AWS (VPC, EKS, ECR, IAM) managed by Terraform
- **CI Pipeline**: Jenkins with automated build, test, security scanning, and image push
- **CD Pipeline**: GitOps with ArgoCD for declarative deployments
- **Container Registry**: AWS ECR (private registry)
- **Orchestration**: Amazon EKS (Kubernetes)
- **Progressive Delivery**: Argo Rollouts (canary deployments)
- **Observability**: Prometheus + Grafana + CloudWatch
- **Security**: IRSA (IAM Roles for Service Accounts), SAST/DAST scanning

## 📁 Repository Structure

This portfolio consists of 3 repositories (simulated in folders):

### 1. `aws-platform-infra/` - Infrastructure as Code
Terraform modules for AWS foundation:
- VPC with public/private subnets
- EKS cluster with managed node groups
- ECR repositories
- IAM roles and IRSA setup
- Jenkins EC2 instance
- S3 backend for state management

### 2. `gitops-eks-platform/` - GitOps Configuration
ArgoCD applications and platform services:
- ArgoCD bootstrap
- App-of-apps pattern
- Environment configurations (dev/staging/prod)
- Platform services (ingress, monitoring, logging)

### 3. `app-microservice-demo/` - Sample Application
Demo microservice with complete CI/CD:
- Node.js/Express API with health/metrics endpoints
- Dockerfile with multi-stage builds
- Jenkinsfile (declarative pipeline)
- Helm chart for Kubernetes deployment
- Unit and integration tests

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with billing alerts set up
2. **Tools installed**:
   ```bash
   # Install required tools
   brew install awscli terraform kubectl helm

   # Or on Linux
   # Follow official installation guides for each tool
   ```
3. **AWS CLI configured**:
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, and region
   ```

### Deployment Steps

#### Phase 1: Infrastructure Setup (30 min)
```bash
cd aws-platform-infra/terraform
terraform init
terraform plan
terraform apply
```

This creates:
- VPC and networking
- EKS cluster (takes ~15 min)
- ECR repositories
- Jenkins EC2 instance
- All IAM roles

#### Phase 2: Jenkins Configuration (15 min)
```bash
# Get Jenkins initial password
cd aws-platform-infra/jenkins
./get-jenkins-password.sh

# Access Jenkins at: http://<jenkins-public-ip>:8080
# Install suggested plugins + Docker, Kubernetes, AWS plugins
# Configure AWS credentials using IRSA (no hardcoded keys!)
```

#### Phase 3: ArgoCD Setup (10 min)
```bash
cd gitops-eks-platform
kubectl apply -k bootstrap/

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD at: https://<argocd-ingress-url>
```

#### Phase 4: Deploy Sample App (5 min)
```bash
cd app-microservice-demo

# Push code to trigger Jenkins pipeline
git add . && git commit -m "Initial commit"
git push

# Jenkins will:
# 1. Build Docker image
# 2. Run tests
# 3. Scan for vulnerabilities
# 4. Push to ECR
# 5. Update GitOps repo
# 6. ArgoCD auto-syncs to EKS
```

## 💰 Cost Breakdown (Approximate)

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| EKS Control Plane | $72 | Fixed cost |
| EC2 Nodes (t3.medium x2) | $60 | Can use t3.small to reduce |
| Jenkins EC2 (t3.small) | $15 | Can stop when not in use |
| NAT Gateway | $32 | Biggest variable cost |
| ECR Storage | $1-5 | Depends on image count |
| Data Transfer | $5-10 | Varies by usage |
| **Total** | **~$185/month** | Can be reduced to ~$100 |

### Cost Optimization Tips
1. **Use Fargate** instead of EC2 nodes (pay per pod)
2. **Stop Jenkins EC2** when not demoing
3. **Use single NAT Gateway** (dev environment)
4. **Delete cluster** after demos, recreate when needed (~30 min)
5. **Use AWS Free Tier** for first 12 months (some services)

## 🎤 Interview Demo Script

### 1. Architecture Overview (5 min)
"I built a production-grade DevOps pipeline demonstrating GitOps and progressive delivery. Let me walk you through the architecture..."

[Show architecture diagram and explain separation of concerns]

### 2. Infrastructure as Code (5 min)
```bash
cd aws-platform-infra/terraform
# Show modules: vpc, eks, jenkins, iam
cat modules/eks/main.tf
```
"I used Terraform modules for reusability. The EKS module creates a cluster with IRSA enabled for secure pod authentication..."

### 3. CI Pipeline (5 min)
```bash
cd app-microservice-demo
cat Jenkinsfile
```
"The Jenkins pipeline has 6 stages: checkout, build, test, security scan, push to ECR, and update GitOps repo. Notice I'm using IRSA instead of hardcoded AWS keys..."

### 4. GitOps & CD (5 min)
```bash
cd gitops-eks-platform
tree environments/
kubectl get applications -n argocd
```
"I'm using ArgoCD's app-of-apps pattern. Each environment (dev/prod) has its own configuration. When Jenkins updates the image tag, ArgoCD auto-syncs..."

### 5. Live Demo (5 min)
```bash
# Make a code change
cd app-microservice-demo/src
# Edit app.js - change version or add endpoint
git commit -am "Demo: Add new feature"
git push

# Show Jenkins build
# Show ArgoCD sync
# Show canary rollout
kubectl argo rollouts get rollout demo-app -n dev --watch

# Show monitoring
# Access Grafana dashboard
```

### 6. Observability (3 min)
"The app exposes Prometheus metrics at /metrics. Grafana dashboards show request rate, error rate, and latency. I also configured SLOs for 99.9% uptime..."

### 7. Q&A Topics You'll Ace
- "How do you handle secrets?" → Sealed Secrets or AWS Secrets Manager with External Secrets Operator
- "How do you ensure zero-downtime deployments?" → Canary rollouts with automatic rollback
- "How do you manage different environments?" → GitOps with kustomize overlays per environment
- "How do you secure the pipeline?" → IRSA, private subnets, security scanning, least privilege IAM
- "What about disaster recovery?" → Infrastructure as Code allows full environment rebuild in 30 min

## 📚 Skills Demonstrated

### Core DevOps
- [x] Infrastructure as Code (Terraform)
- [x] CI/CD Pipeline Design
- [x] Container Orchestration (Kubernetes)
- [x] GitOps Methodology
- [x] Configuration Management

### AWS Services
- [x] EKS (Elastic Kubernetes Service)
- [x] ECR (Elastic Container Registry)
- [x] VPC & Networking
- [x] IAM & Security (IRSA)
- [x] CloudWatch & Observability

### Tools & Technologies
- [x] Jenkins (Declarative Pipelines)
- [x] ArgoCD (GitOps)
- [x] Argo Rollouts (Progressive Delivery)
- [x] Helm (Package Management)
- [x] Prometheus & Grafana (Monitoring)
- [x] Docker (Containerization)

### Best Practices
- [x] Multi-stage Docker builds
- [x] Least privilege IAM
- [x] Secrets management
- [x] Security scanning
- [x] Blue-green & canary deployments
- [x] Infrastructure testing
- [x] Documentation

## 🔐 Security Best Practices

1. **No Hardcoded Credentials**: Using IRSA for AWS authentication
2. **Private Subnets**: Application nodes not directly internet-accessible
3. **Security Scanning**: Trivy scans Docker images for vulnerabilities
4. **Least Privilege**: Each service has minimal IAM permissions
5. **Network Policies**: Pod-to-pod communication restrictions
6. **Image Signing**: (Optional) Cosign for image verification

## 🧪 Testing Strategy

- **Unit Tests**: Jest for application logic
- **Integration Tests**: Supertest for API endpoints
- **Infrastructure Tests**: Terratest for Terraform modules
- **Security Tests**: Trivy, Checkov for IaC scanning
- **Smoke Tests**: Post-deployment health checks

## 📈 Monitoring & SLOs

### Service Level Objectives
- **Availability**: 99.9% uptime
- **Latency**: p95 < 200ms, p99 < 500ms
- **Error Rate**: < 0.1% of requests

### Dashboards
- Application metrics (requests, latency, errors)
- Infrastructure metrics (CPU, memory, disk)
- Jenkins build metrics
- ArgoCD sync status

## 🗺️ Roadmap & Extensions

### Phase 2 Enhancements (Future)
- [ ] Multi-region deployment
- [ ] Service mesh (Istio/Linkerd)
- [ ] Chaos engineering (Chaos Mesh)
- [ ] Policy enforcement (OPA/Gatekeeper)
- [ ] Cost optimization automation
- [ ] Automated backup/restore
- [ ] SIEM integration

## 📖 Additional Resources

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [GitOps Principles](https://opengitops.dev/)
- [12-Factor App Methodology](https://12factor.net/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

## 📝 Notes for Interviews

### Why This Architecture?
"I chose this architecture because it represents how enterprises actually deploy applications. The separation between CI (Jenkins) and CD (ArgoCD) follows GitOps principles where the Git repository is the single source of truth. This enables better auditability, rollback capabilities, and separation of concerns."

### Why GitOps over Traditional CD?
"GitOps provides declarative configuration, version control for infrastructure, and easy rollbacks. Unlike traditional CD where CI tools push to production, GitOps uses a pull model where ArgoCD continuously reconciles cluster state with Git. This is more secure and auditable."

### Cost Considerations
"I'm aware this costs ~$185/month. For production, the cost is justified by reliability and scalability. For this demo, I can tear down and rebuild in 30 minutes using Terraform, so I only run it when needed."

---

**Built by**: Shaik Shafivulla
**LinkedIn**: [Your LinkedIn URL]
**GitHub**: [Your GitHub URL]
**Email**: [Your Email]

*This portfolio is maintained and regularly updated to reflect current DevOps best practices.*
