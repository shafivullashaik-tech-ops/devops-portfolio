# DevOps Portfolio — AWS EKS · Jenkins · GitOps · LLMOps

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/eks/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Jenkins](https://img.shields.io/badge/Jenkins-CI-D24939?logo=jenkins&logoColor=white)](https://www.jenkins.io/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-LLM%20Gateway-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> A production-ready DevOps + LLMOps portfolio demonstrating enterprise-grade CI/CD, GitOps, observability, infrastructure as code, and an AI RAG Gateway — all running on AWS EKS.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Accessing Services](#accessing-services)
- [Best Practices Demonstrated](#best-practices-demonstrated)
- [Technology Stack](#technology-stack)
- [Cost Optimization](#cost-optimization)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Cleanup](#cleanup)
- [License](#license)
- [Contact](#contact)

---

## Overview

This portfolio contains **5 production-grade projects** that together form a complete DevOps + LLMOps platform:

| # | Project | What it demonstrates |
|---|---------|---------------------|
| 1 | `terraform-aws-modules/` | Reusable IaC modules for AWS (VPC, EKS, ECR, IAM, ACM, Route 53) |
| 2 | `aws-platform-infra/` | Environment-specific Terraform configs consuming those modules |
| 3 | `gitops-eks-platform/` | ArgoCD app-of-apps GitOps platform with full environment promotion |
| 4 | `app-microservice-demo/` | Node.js microservice with Jenkins CI, Helm, HPA, and full test suite |
| 5 | `sre-observability-stack/` | Prometheus · Grafana · Loki · Tempo · OTel · GameDay · Runbooks |
| 6 | `llmops-rag-gateway/` | Production LLM Gateway (FastAPI) with RAG, guardrails, eval harness |

---

## Architecture

### High-Level Flow

```
Developer → GitHub → Jenkins (CI) → ECR → GitOps Repo → ArgoCD (CD) → EKS → Monitoring
                                                                              ↑
                                                                     Prometheus · Loki · Tempo
```

### Full 5-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 1 — AWS Infrastructure (Terraform)                               │
│                                                                         │
│  AWS Cloud (us-west-2)                                                  │
│  ├── VPC (10.0.0.0/16)                                                  │
│  │   ├── us-west-2a  │ Public Subnet (ALB)  │ Private Subnet (EKS)     │
│  │   └── us-west-2b  │ Public Subnet (ALB)  │ Private Subnet (EKS)     │
│  ├── EKS Cluster (portfolio-eks-dev)                                    │
│  │   ├── Node Group — t3.medium × 2  (platform services)               │
│  │   └── Node Group — t3.large  × 2  (application workloads)           │
│  ├── ECR Repositories  (demo-app · llm-gateway)                        │
│  ├── IAM + IRSA Roles  (Jenkins · EBS CSI · LLM Gateway)               │
│  ├── ACM (SSL/TLS) · Route 53 (DNS)                                    │
│  └── S3 + DynamoDB  (Terraform remote state + lock)                    │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 2 — Kubernetes Namespaces                                        │
│                                                                         │
│  argocd      → ArgoCD (GitOps controller)                               │
│  jenkins     → Jenkins (CI pipelines)                                   │
│  monitoring  → Prometheus · Grafana · Loki · Tempo                     │
│  llmops      → LLM RAG Gateway (FastAPI + pgvector)                    │
│  default     → demo-app (Node.js microservice)                          │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 3 — CI/CD Pipeline                                               │
│                                                                         │
│  git push → GitHub webhook → Jenkins                                    │
│    1. Checkout   2. Test/Lint   3. Docker build (multi-stage)           │
│    4. Security scan (Trivy)     5. Push → ECR                           │
│    6. Update image tag in GitOps repo                                   │
│  ArgoCD detects diff → Rolling deploy → Health check ✅                 │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 4 — LLM Gateway (RAG)                                            │
│                                                                         │
│  POST /chat ──► JWT Auth ──► Rate Limiter ──► Guardrails               │
│    ──► RAG Retriever (pgvector) ──► LLM API ──► Response + Citations   │
│                                                                         │
│  CI Eval Gate: groundedness ≥ 70% · citation rate ≥ 80% · refusal 100% │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 5 — Observability (Three Pillars)                                │
│                                                                         │
│  Metrics  → Prometheus + Grafana (Golden Signals: LETS)                │
│  Logs     → Loki + Promtail (structured JSON, trace_id correlation)    │
│  Traces   → Tempo + OpenTelemetry (end-to-end distributed tracing)     │
│  Alerts   → Alertmanager → PagerDuty/Slack + Runbooks                  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
devops-portfolio/
├── 📄 README.md                        ← This file
├── 📄 ARCHITECTURE.md                  ← Detailed architecture docs
├── 📄 DEPLOYMENT.md                    ← Step-by-step deployment guide
│
├── 🏗️  terraform-aws-modules/          ← Reusable Terraform modules
│   ├── vpc/                            ← VPC, subnets, IGW, NAT, route tables
│   ├── eks/                            ← EKS cluster, node groups, addons
│   ├── ecr/                            ← Container registry + lifecycle policies
│   ├── iam/                            ← IAM roles, policies, IRSA
│   ├── acm/                            ← SSL/TLS certificate provisioning
│   ├── route53/                        ← DNS records and hosted zones
│   ├── jenkins/                        ← Jenkins infrastructure resources
│   └── monitoring/                     ← Monitoring infrastructure
│
├── ☁️  aws-platform-infra/             ← Environment-specific Terraform
│   ├── terraform/environments/dev/     ← Dev environment config
│   ├── terraform/environments/prod/    ← Prod environment config
│   ├── jenkins/                        ← Jenkins Helm values
│   ├── scripts/
│   │   ├── setup-backend.sh            ← Bootstrap S3 + DynamoDB for state
│   │   └── post-apply-deploy.sh        ← One-command post-apply setup
│   └── Jenkinsfile                     ← Infrastructure CI/CD pipeline
│
├── ☸️  gitops-eks-platform/            ← ArgoCD GitOps configuration
│   ├── bootstrap/                      ← ArgoCD installation (kustomize)
│   ├── apps/
│   │   └── app-of-apps.yaml            ← Root app managing all child apps
│   ├── platform-services/              ← Monitoring, Ingress-nginx
│   ├── environments/
│   │   ├── dev/                        ← Auto-sync, lower replicas
│   │   └── prod/                       ← Manual approval, production limits
│   └── rbac/                           ← ArgoCD RBAC configuration
│
├── 🟢 app-microservice-demo/           ← Node.js microservice
│   ├── src/                            ← Express.js app + Winston logging
│   ├── helm/                           ← Helm chart (Deployment, HPA, Ingress)
│   ├── tests/                          ← Unit + integration tests (Jest)
│   ├── Dockerfile                      ← Multi-stage build, non-root user
│   └── Jenkinsfile                     ← 7-stage CI/CD pipeline
│
├── 📊 sre-observability-stack/         ← SRE tooling & practices
│   ├── monitoring/                     ← kube-prometheus-stack Helm values
│   │   ├── dashboards/                 ← Golden Signals Grafana dashboard
│   │   └── alerts/                     ← PrometheusRule CRDs
│   ├── logging/                        ← Loki + Promtail stack
│   ├── tracing/                        ← Tempo + OTel Collector
│   ├── load-tests/                     ← k6 load + chaos/GameDay scripts
│   └── runbooks/                       ← Incident response playbooks
│       ├── crashloop.md
│       ├── high-error-rate.md
│       └── high-latency.md
│
├── 🤖 llmops-rag-gateway/              ← LLM + RAG API service
│   ├── app/
│   │   ├── main.py                     ← FastAPI entry point
│   │   ├── routers/                    ← /chat · /rag/chat · /health
│   │   ├── middleware/                 ← JWT auth · rate limiter · guardrails
│   │   ├── rag/                        ← Ingest · chunk · pgvector store · retrieve
│   │   ├── llm/                        ← OpenAI/Stub client + LRU cache
│   │   └── observability/              ← Prometheus metrics + structured logging
│   ├── eval/                           ← Golden dataset + CI eval harness
│   ├── helm/                           ← Kubernetes Helm chart
│   ├── k8s/                            ← Raw manifests + ServiceMonitor
│   ├── scripts/                        ← Token generator + doc ingestion
│   ├── tests/                          ← pytest unit + integration tests
│   └── Jenkinsfile                     ← 8-stage pipeline with Eval Gate
│
└── 📁 docs/
    ├── diagrams/                       ← draw.io architecture diagrams
    ├── gameday.md                      ← Chaos engineering exercises
    └── postmortems/                    ← Blameless incident reviews
```

---

## Features

### Infrastructure as Code
- **Modular Terraform** — reusable, versioned modules for VPC, EKS, ECR, IAM, ACM, Route 53
- **Remote state** — S3 backend with DynamoDB state locking and encryption
- **Multi-AZ** — resources deployed across 2 Availability Zones (us-west-2a / us-west-2b)
- **Immutable infrastructure** — tear down and recreate environments reproducibly

### CI/CD Pipeline
- **Declarative Jenkins pipelines** — Checkout → Test → Build → Scan → Push → GitOps Update → Notify
- **Parallel execution** — tests and security scans run in parallel to reduce pipeline time
- **Immutable artifacts** — Docker images tagged with build numbers, pushed to ECR
- **Separation of CI and CD** — Jenkins handles CI; ArgoCD handles CD via GitOps

### GitOps & Deployments
- **ArgoCD app-of-apps** — single root application manages all child apps declaratively
- **Auto-sync + self-heal** — ArgoCD detects and corrects drift automatically
- **Environment promotion** — dev (auto-sync) → prod (manual approval gate)
- **Instant rollback** — `git revert` reverts any deployment in seconds

### LLMOps / AI Gateway
- **FastAPI LLM Gateway** — JWT-authenticated, rate-limited REST API for LLM interactions
- **RAG pipeline** — document ingestion → chunking → pgvector embedding → semantic retrieval → LLM response with citations
- **Guardrails** — prompt injection detection, PII redaction, DAN/jailbreak blocking
- **Eval harness** — automated CI quality gate (groundedness ≥ 70%, citation rate ≥ 80%, refusal rate 100%)
- **Cost controls** — stub mode, LRU response/embedding cache, token usage tracking in Grafana

### Observability (Three Pillars)
- **Metrics** — Prometheus + Grafana with Golden Signals dashboards (Latency, Traffic, Errors, Saturation)
- **Logs** — Loki + Promtail with structured JSON logging and `trace_id` correlation
- **Traces** — Tempo + OpenTelemetry for end-to-end distributed request tracing
- **Alerts** — PrometheusRule CRDs linked to SRE runbooks via `runbook_url` annotation

### Security
- **IRSA** — pod-level AWS permissions; no node-level credentials, no hardcoded secrets
- **Private subnets** — all EKS worker nodes in private subnets; only ALB is public-facing
- **Image scanning** — Trivy CVE scan on every build; `npm audit` for Node.js dependencies
- **Least privilege IAM** — separate role per service (Jenkins, EBS CSI, LLM Gateway)
- **Container hardening** — non-root user (UID 1001), dropped capabilities, security headers

### Reliability & SRE
- **Health probes** — liveness + readiness on every pod
- **HPA** — Horizontal Pod Autoscaler on CPU/memory metrics
- **PodDisruptionBudgets** — zero-downtime rolling deployments
- **Runbooks** — documented step-by-step mitigation for every alert (CrashLoop, High Error Rate, High Latency)
- **GameDay exercises** — planned chaos engineering scenarios with k6
- **Postmortems** — blameless incident review process

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose | Install |
|------|---------|---------|---------|
| **AWS CLI** | 2.x | AWS resource management | [Guide](https://aws.amazon.com/cli/) |
| **Terraform** | 1.5+ | Infrastructure provisioning | [Guide](https://www.terraform.io/downloads) |
| **kubectl** | 1.28+ | Kubernetes management | [Guide](https://kubernetes.io/docs/tasks/tools/) |
| **Helm** | 3.x | Kubernetes package manager | [Guide](https://helm.sh/docs/intro/install/) |
| **Docker** | 20.x+ | Container build & runtime | [Guide](https://docs.docker.com/get-docker/) |
| **Python** | 3.11+ | LLM Gateway / eval scripts | [Guide](https://www.python.org/downloads/) |
| **Node.js** | 18.x+ | Demo microservice | [Guide](https://nodejs.org/) |
| **git** | 2.x+ | Version control | [Guide](https://git-scm.com/downloads) |

### AWS Configuration

```bash
# Configure AWS credentials (this project uses the 'shafi' profile)
aws configure --profile shafi
# Default region: us-west-2

# Verify configuration
aws sts get-caller-identity --profile shafi
```

### AWS Account Requirements

- Active AWS account with programmatic access
- IAM user/role with permissions for: EKS, VPC, ECR, IAM, S3, DynamoDB, ACM, Route 53, CloudWatch
- Sufficient service limits for EKS clusters, VPCs, and EC2 instances
- Budget awareness: **~$185/month** for the dev environment (see [Cost Optimization](#cost-optimization))

---

## Quick Start

### Step 1 — Bootstrap Terraform Backend

```bash
cd aws-platform-infra/scripts
chmod +x setup-backend.sh
./setup-backend.sh dev us-west-2
# Creates: S3 bucket (devops-portfolio-tfstate-dev) + DynamoDB lock table
```

### Step 2 — Deploy AWS Infrastructure

```bash
cd aws-platform-infra/terraform/environments/dev
terraform init
terraform plan
terraform apply   # ~15–20 minutes
```

Save the outputs — you'll need them for Jenkins and ECR configuration:

```bash
terraform output cluster_name           # portfolio-eks-dev
terraform output jenkins_irsa_role_arn
terraform output ecr_repository_url
```

### Step 3 — Configure kubectl

```bash
aws eks update-kubeconfig \
  --name portfolio-eks-dev \
  --region us-west-2 \
  --profile shafi

kubectl cluster-info
kubectl get nodes   # expect 2 nodes in Ready state
```

### Step 4 — Deploy ArgoCD + All Platform Services

```bash
# Bootstrap ArgoCD
kubectl create namespace argocd
kubectl apply -k gitops-eks-platform/bootstrap/ --server-side

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Deploy app-of-apps (this manages ALL other platform services automatically)
kubectl apply -f gitops-eks-platform/apps/app-of-apps.yaml
```

### Step 5 (Optional) — One-Command Post-Deploy Setup

```bash
# Alternatively, run Steps 3–4 automatically after terraform apply:
cd aws-platform-infra/scripts
chmod +x post-apply-deploy.sh
./post-apply-deploy.sh us-west-2
```

> 📖 For the complete step-by-step guide including Jenkins, Monitoring, and LLM Gateway setup, see **[DEPLOYMENT.md](DEPLOYMENT.md)**.

---

## Accessing Services

Run each in a separate terminal:

```bash
# ArgoCD UI — https://localhost:8080
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret \
#             -o jsonpath="{.data.password}" | base64 -d

# Grafana UI — http://localhost:3000
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# Username: admin  |  Password: Admin@1234!

# Jenkins UI — http://localhost:8090
kubectl port-forward svc/jenkins -n jenkins 8090:8080
# Username: admin  |  Password: see DEPLOYMENT.md Step 8d

# LLM Gateway — http://localhost:8000
kubectl port-forward svc/llm-gateway -n llmops 8000:8000
# Swagger UI: http://localhost:8000/docs

# Demo App — http://localhost:3001
kubectl port-forward svc/demo-app -n default 3001:3000
```

### Quick Status Check

```bash
kubectl get pods --all-namespaces        # All pods should be Running/Completed
helm list --all-namespaces               # All Helm releases
kubectl get applications -n argocd       # ArgoCD app health
```

---

## Best Practices Demonstrated

### Infrastructure as Code
| Practice | Implementation |
|----------|---------------|
| Modular design | Reusable modules for every AWS resource type |
| Remote state | S3 backend + DynamoDB state locking |
| Environment parity | Same modules used for dev and prod with different `tfvars` |
| Multi-AZ | All resources span 2 Availability Zones |
| Immutable infra | Never patch running resources; replace them |

### CI/CD
| Practice | Implementation |
|----------|---------------|
| Declarative pipelines | Jenkins declarative syntax with shared stages |
| Parallel stages | Tests and security scans run in parallel |
| Semantic versioning | Images tagged with `BUILD_NUMBER-SHORT_SHA` |
| GitOps separation | CI pushes image tag to GitOps repo; ArgoCD handles CD |
| Manual approval gates | Production deployments require explicit approval |

### Kubernetes
| Practice | Implementation |
|----------|---------------|
| Multi-stage builds | Optimised Docker images (~150 MB for Node.js app) |
| Non-root containers | UID 1001 with dropped capabilities |
| Resource limits | CPU + Memory requests/limits on all pods |
| Health probes | Readiness and liveness on every Deployment |
| Auto-scaling | HPA based on CPU/memory metrics |
| High availability | PodDisruptionBudgets + multi-AZ node groups |

### Security
| Practice | Implementation |
|----------|---------------|
| IRSA | Pod-level AWS permissions — no node IAM credentials |
| Private workloads | EKS nodes in private subnets; only ALB is public |
| Image scanning | Trivy CVE scan on every build |
| Dependency scanning | `npm audit` + `ruff` + `hadolint` in CI |
| Secrets management | Kubernetes Secrets — no hardcoded values in code |
| AI guardrails | Prompt injection + PII redaction on all LLM calls |

### Observability
| Practice | Implementation |
|----------|---------------|
| Metrics | Prometheus scraping all workloads via ServiceMonitor |
| Dashboards | Grafana Golden Signals (Latency · Traffic · Errors · Saturation) |
| Logs | Loki + Promtail with structured JSON and `trace_id` injection |
| Traces | Tempo + OpenTelemetry SDK in application code |
| Correlation | `trace_id` in every log line — click from Loki to Tempo |
| Runbooks | Linked from every alert via `runbook_url` annotation |
| GameDays | Planned chaos exercises using k6 failure injection scripts |
| Postmortems | Blameless structured reviews committed to the repo |

### LLMOps
| Practice | Implementation |
|----------|---------------|
| Gateway pattern | Single FastAPI entry point for all LLM traffic |
| RAG | pgvector retrieval with citation traceability |
| Eval CI gate | Quality thresholds enforced on every build |
| Cost controls | Stub mode + LRU cache + token Prometheus metrics |
| Guardrails | Injection blocking, PII redaction, system prompt hardening |

---

## Technology Stack

| Category | Tools |
|----------|-------|
| **Cloud** | AWS (VPC · EKS · ECR · IAM · ACM · Route 53 · CloudWatch) |
| **IaC** | Terraform 1.5+ |
| **CI** | Jenkins |
| **CD / GitOps** | ArgoCD |
| **Container Orchestration** | Kubernetes (EKS 1.28+) |
| **Container Registry** | AWS ECR |
| **Metrics** | Prometheus · Grafana |
| **Logs** | Loki · Promtail |
| **Traces** | Tempo · OpenTelemetry |
| **Load Testing** | k6 |
| **LLM / AI** | OpenAI API · FastAPI · pgvector · Redis (LRU cache) |
| **Languages** | Python 3.11 · Node.js 18 · Bash |
| **Packaging** | Docker · Helm 3 |
| **Security Scanning** | Trivy · npm audit · Hadolint · ruff |
| **Testing** | pytest · Jest |

---

## Cost Optimization

### Dev Environment — ~$185/month

| Resource | Cost/month |
|----------|-----------|
| EKS Control Plane | ~$72 |
| EC2 Nodes (2× t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| EBS, ECR, CloudWatch, other | ~$21 |
| **Total** | **~$185** |

### Optimizations Applied

- **Single NAT Gateway** in dev (vs. one per AZ in prod)
- **Right-sized instances** — t3.medium for platform, t3.large for apps
- **ECR lifecycle policies** — automatically expire old untagged images
- **LLM stub mode** — `LLM_BACKEND=stub` in CI/dev to avoid OpenAI API charges
- **LRU response cache** — identical LLM requests served from cache (zero API cost)
- **Tear-down scripts** — `terraform destroy` removes everything; rebuild in ~20 minutes

> 💡 **Tip:** Run `terraform destroy` when the cluster is not in use to reduce costs to near zero.

---

## Documentation

| Document | Description |
|----------|-------------|
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Detailed 5-layer architecture, traffic flow, component interactions |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Complete step-by-step deployment guide (10 steps) |
| **[docs/gameday.md](docs/gameday.md)** | Chaos engineering GameDay walkthrough |
| **[docs/postmortems/](docs/postmortems/)** | Blameless postmortem incident reviews |
| **[sre-observability-stack/runbooks/crashloop.md](sre-observability-stack/runbooks/crashloop.md)** | Runbook: Pod CrashLoopBackOff |
| **[sre-observability-stack/runbooks/high-error-rate.md](sre-observability-stack/runbooks/high-error-rate.md)** | Runbook: High Error Rate |
| **[sre-observability-stack/runbooks/high-latency.md](sre-observability-stack/runbooks/high-latency.md)** | Runbook: High Latency |
| **Sub-project READMEs** | Each module/component has its own detailed README |

---

## Troubleshooting

### 1. Terraform Backend Not Initialized

```bash
# Error: Backend initialization required
cd aws-platform-infra/scripts
./setup-backend.sh dev us-west-2
```

### 2. kubectl Cannot Connect to Cluster

```bash
# Error: The connection to the server localhost:8080 was refused
aws eks update-kubeconfig \
  --name portfolio-eks-dev \
  --region us-west-2 \
  --profile shafi
kubectl cluster-info
```

### 3. ArgoCD Sync Issues

```bash
# Check application status
kubectl get applications -n argocd

# View detailed sync status
argocd app get <app-name>

# Force sync
argocd app sync <app-name> --force
```

### 4. ECR Authentication Errors

```bash
# Refresh ECR login token
aws ecr get-login-password --region us-west-2 --profile shafi | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-west-2.amazonaws.com
```

### 5. Jenkins Pod Stuck in Pending

```bash
# Most common cause: PVC not binding (storage class issue)
kubectl describe pod jenkins-0 -n jenkins
kubectl get pvc -n jenkins
```

### 6. LLM Gateway — OpenAI Auth Error

```bash
# Ensure OPENAI_API_KEY is set in your .env or Kubernetes Secret
# For local dev, use stub mode:
LLM_BACKEND=stub docker compose up -d
```

### 7. Insufficient AWS Permissions

```bash
aws iam get-user --profile shafi
aws iam list-attached-user-policies --user-name <your-username> --profile shafi
```

### Getting Help

- 🐛 [GitHub Issues](https://github.com/shafivullashaik-tech-ops/devops-portfolio/issues) — known bugs and feature requests
- 📖 [SRE Runbooks](sre-observability-stack/runbooks/) — operational guidance for common incidents
- 📋 CloudWatch Logs + `kubectl describe pod` — most runtime errors appear here

---

## Contributing

Contributions and suggestions are welcome! This is a portfolio project — improvements are appreciated.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** — follow existing code style and update relevant documentation
4. **Run linters and tests**
   ```bash
   terraform fmt -recursive && terraform validate    # for Terraform changes
   npm test                                          # for Node.js changes
   ruff check . && pytest                            # for Python changes
   ```
5. **Commit** using [Conventional Commits](https://www.conventionalcommits.org/)
   ```bash
   git commit -m "feat: describe your change"
   ```
6. **Push and open a Pull Request**

### Contribution Guidelines

- **Never** commit credentials, secrets, or `.env` files
- **Always** run `terraform fmt` and `terraform validate` before committing Terraform
- **Update** the relevant README and docs alongside code changes
- **Test** infrastructure changes in a dev environment before raising a PR

---

## Cleanup

### Destroy All AWS Infrastructure

> ⚠️ Do this when you're done to avoid ~$185/month in AWS charges.

```bash
# Step 1: Remove Helm releases
helm uninstall jenkins -n jenkins
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall loki-stack -n monitoring

# Step 2: Remove ArgoCD
kubectl delete -k gitops-eks-platform/bootstrap/

# Step 3: Destroy all Terraform-managed AWS resources (~5 minutes)
cd aws-platform-infra/terraform/environments/dev
terraform destroy
# Type 'yes' when prompted
```

### Verify Everything is Deleted

```bash
aws eks list-clusters --region us-west-2 --profile shafi
aws ec2 describe-vpcs --region us-west-2 --profile shafi \
  --query 'Vpcs[?Tags[?Key==`Project` && Value==`portfolio`]]'
aws ecr describe-repositories --region us-west-2 --profile shafi
```

> **Note:** Terraform destroy removes all resources it manages. Manually verify to avoid unexpected charges.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Contact

**Shaik Shafivulla** — DevOps / Platform / SRE Engineer

- 🐙 **GitHub**: [@shafivullashaik-tech-ops](https://github.com/shafivullashaik-tech-ops)
- 💼 **LinkedIn**: [linkedin.com/in/shafivulla-shaik-b4b520120](https://linkedin.com/in/shafivulla-shaik-b4b520120)
- 📧 **Email**: [shafivullashaik916@gmail.com](mailto:shafivullashaik916@gmail.com)

---

**Project Status**: ✅ Production-ready | Actively maintained  
**Last Updated**: April 2026

⭐ If you found this project useful, please consider giving it a star!
