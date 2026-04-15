# 🏗️ DevOps Portfolio — Architecture Documentation

> **GitHub Repo:** [shafivullashaik-tech-ops/devops-portfolio](https://github.com/shafivullashaik-tech-ops/devops-portfolio)

---

## 📐 Architecture Diagrams

> Open `.drawio` files with [draw.io Desktop](https://www.drawio.com/) or [app.diagrams.net](https://app.diagrams.net/)

| Diagram | File | Description |
|---------|------|-------------|
| **Infrastructure** | [`docs/diagrams/infrastructure-architecture.drawio`](docs/diagrams/infrastructure-architecture.drawio) | AWS VPC, EKS, subnets, ECR, IAM, traffic flow |
| **CI/CD Pipeline** | [`docs/diagrams/cicd-pipeline.drawio`](docs/diagrams/cicd-pipeline.drawio) | Jenkins → ECR → ArgoCD → EKS + LLM RAG flow |

---

## 🌐 Layer 1 — AWS Infrastructure (Terraform)

### Infrastructure Overview

```
AWS Cloud (us-west-2)
├── VPC (10.0.0.0/16)
│   ├── Availability Zone A (us-west-2a)
│   │   ├── Public Subnet  10.0.1.0/24  ← ALB (Load Balancer)
│   │   └── Private Subnet 10.0.3.0/24  ← EKS Worker Nodes
│   ├── Availability Zone B (us-west-2b)
│   │   ├── Public Subnet  10.0.2.0/24  ← ALB (Load Balancer)
│   │   └── Private Subnet 10.0.4.0/24  ← EKS Worker Nodes
│   ├── Internet Gateway   ← Public internet access
│   └── NAT Gateway        ← Private nodes outbound access
├── EKS Cluster
│   ├── Control Plane (AWS Managed)
│   ├── Node Group — t3.medium × 2  (platform services)
│   └── Node Group — t3.large  × 2  (application workloads)
├── ECR Repositories
│   ├── demo-app
│   └── llm-gateway
├── IAM Roles
│   ├── EKS Node Role       ← EC2 nodes call AWS APIs
│   ├── Jenkins Role        ← Push images to ECR
│   └── LLM Gateway IRSA    ← Pod-level AWS permissions
├── ACM (SSL/TLS Certificates)
├── Route 53 (DNS)
└── S3 + DynamoDB           ← Terraform remote state + lock
```

### Terraform Module Structure

```
terraform-aws-modules/
├── vpc/          ← VPC, subnets, IGW, NAT, route tables
├── eks/          ← EKS cluster, node groups, addons
├── ecr/          ← Docker image repositories + lifecycle
├── iam/          ← IAM roles, policies, IRSA
├── acm/          ← SSL/TLS certificate provisioning
├── route53/      ← DNS records and hosted zones
└── jenkins/      ← Jenkins infrastructure resources

aws-platform-infra/terraform/
├── environments/dev/   ← Dev environment (uses modules above)
└── environments/prod/  ← Prod environment (uses modules above)
```

### Traffic Flow (numbered steps)
```
1. User → Internet Gateway (public internet)
2. IGW  → Application Load Balancer (public subnet)
3. ALB  → EKS Worker Nodes (private subnet, port forward)
4. Nodes → NAT Gateway (outbound: pull images, call APIs)
5. EKS Control Plane → Manages all worker nodes
6. GitHub Webhook → Triggers Jenkins (CI)
7. Jenkins → Builds image, pushes to ECR
8. ArgoCD → Pulls image from ECR, deploys to pods
```

---

## ☸️ Layer 2 — Kubernetes (EKS)

### Namespaces & Workloads

| Namespace | Workload | Purpose |
|-----------|---------|---------|
| `argocd` | ArgoCD | GitOps continuous deployment controller |
| `jenkins` | Jenkins | CI/CD pipelines |
| `monitoring` | Prometheus | Metrics collection & alerting |
| `monitoring` | Grafana | Unified observability dashboards |
| `monitoring` | Loki | Log aggregation |
| `monitoring` | Tempo | Distributed tracing |
| `llmops` | llm-gateway | LLM/RAG API service (Python/FastAPI) |
| `default` | demo-app | Node.js microservice demo |

### App-of-Apps (ArgoCD)

```
app-of-apps (parent)
├── jenkins
├── kube-prometheus-stack
├── loki-stack
├── tempo
├── demo-app
└── llm-gateway
```

---

## 🔄 Layer 3 — CI/CD Pipeline

### Complete Flow

```
Developer pushes code
        ↓
GitHub (PR → merge to main)
        ↓ webhook
Jenkins CI Pipeline
  ├── 1. Checkout code
  ├── 2. Run tests (npm test / pytest)
  ├── 3. Docker build (multi-stage)
  ├── 4. Security scan (Trivy)
  ├── 5. Push image → ECR (tagged with build#)
  └── 6. Update image tag in GitOps repo
        ↓ git push
ArgoCD detects change
  ├── Compare desired (Git) vs actual (K8s)
  ├── Apply Helm chart (kubectl apply)
  ├── Rolling update (zero downtime)
  └── Health check (readiness/liveness probes)
        ↓
Application live in EKS ✅
        ↓
Prometheus/Loki/Tempo collect telemetry
        ↓
Grafana shows metrics + logs + traces
```

---

## 🤖 Layer 4 — LLM Gateway (AI Application)

### What is LLM + RAG?

**LLM (Large Language Model):** An AI that understands and generates text (GPT-4, Claude, Llama, etc.)

**RAG (Retrieval-Augmented Generation):**
```
Without RAG:
  User: "What is our leave policy?"
  LLM:  "I don't know your company policy" ❌

With RAG:
  1. Search company documents for "leave policy"
  2. Find: "Employees get 20 days annual leave..."
  3. Send document context + question to LLM
  LLM:  "Based on your policy, you get 20 days" ✅
```

### LLM Gateway Request Flow

```
User Request (POST /chat)
        ↓
JWT Auth Middleware     ← Verify bearer token
        ↓
Rate Limiter            ← 10 requests/minute per user
        ↓
Guardrails              ← Block harmful/malicious prompts
        ↓
RAG Retriever           ← Embed query → search FAISS → top-3 docs
        ↓
Cache Check (Redis)     ← Return cached response if exists
        ↓
LLM API Call            ← OpenAI/Ollama + context + question
        ↓
Response + Cache Store  ← Store for future identical queries
        ↓
Observability           ← Prometheus metrics, Loki log, Tempo trace
        ↓
Response to User        ← {"answer": "...", "sources": [...]}
```

### LLM Gateway Code Structure

```
llmops-rag-gateway/app/
├── main.py                 ← FastAPI application entry point
├── routers/
│   ├── chat.py             ← POST /chat — conversational AI
│   ├── rag.py              ← POST /rag/ingest — upload documents
│   └── health.py           ← GET  /health — liveness check
├── middleware/
│   ├── auth.py             ← JWT token validation
│   ├── rate_limiter.py     ← Per-user rate limiting
│   └── guardrails.py       ← Prompt safety filtering
├── rag/
│   ├── ingestion.py        ← Load PDFs/text files
│   ├── chunking.py         ← Split into 500-word overlapping chunks
│   ├── store.py            ← FAISS vector database
│   └── retriever.py        ← Semantic similarity search
├── llm/
│   ├── client.py           ← OpenAI/Ollama API client
│   └── cache.py            ← Redis response cache
└── observability/
    ├── metrics.py          ← Prometheus counters/histograms
    └── logger.py           ← Structured JSON logging
```

---

## 📊 Layer 5 — Observability (SRE)

### The Three Pillars

| Pillar | Tool | What it answers |
|--------|------|-----------------|
| **Metrics** | Prometheus → Grafana | "How many requests/sec? CPU usage? Error rate?" |
| **Logs** | Loki → Grafana | "What happened at 10:00 PM? Show ERROR logs" |
| **Traces** | Tempo → Grafana | "Why did this request take 3 seconds? Which service?" |

### SRE Practices

```
sre-observability-stack/
├── load-tests/
│   ├── high-error-rate.js  ← k6: simulate 500 errors
│   └── high-latency.js     ← k6: simulate slow responses
├── runbooks/
│   ├── crashloop.md        ← Steps when pod is crash-looping
│   ├── high-error-rate.md  ← Steps when error rate spikes
│   └── high-latency.md     ← Steps when latency is high
└── docs/
    ├── gameday.md          ← Planned chaos engineering
    └── postmortems/001.md  ← Post-incident review
```

---

## 🏆 Best Practices Summary

### Infrastructure
| Practice | Implementation |
|----------|---------------|
| Infrastructure as Code | All AWS resources managed by Terraform |
| Module reuse | Reusable modules for VPC/EKS/ECR/IAM |
| Remote state | S3 backend + DynamoDB state locking |
| Multi-AZ | Resources span 2 Availability Zones |
| Private workloads | EKS nodes in private subnets |
| Least privilege | Separate IAM role per service (IRSA) |

### Application
| Practice | Implementation |
|----------|---------------|
| Containerization | Docker multi-stage builds |
| Helm charts | Templated K8s manifests for all apps |
| Health checks | Readiness + Liveness probes on all pods |
| Auto-scaling | HPA based on CPU/memory metrics |
| Resource limits | CPU/Memory requests+limits on all pods |

### Security
| Practice | Implementation |
|----------|---------------|
| Authentication | JWT bearer tokens for API access |
| Rate limiting | Per-user request throttling |
| AI Guardrails | Prompt injection and harm detection |
| IRSA | Pod-level AWS permissions, not node-level |
| Secrets | Kubernetes Secrets, not hardcoded |

### Reliability
| Practice | Implementation |
|----------|---------------|
| GitOps | ArgoCD as source-of-truth enforcer |
| Rollback | `git revert` instantly reverts deployments |
| Drift detection | ArgoCD auto-corrects manual changes |
| Runbooks | Documented response for every alert type |
| GameDays | Planned chaos testing exercises |
| Postmortems | Blameless incident review process |

---

## 📁 Repository Structure

```
devops-portfolio/
├── 📄 README.md                    ← Project overview
├── 📄 ARCHITECTURE.md              ← This file
├── 📄 DEPLOYMENT.md                ← Step-by-step deployment guide
│
├── 🗂️ docs/diagrams/
│   ├── infrastructure-architecture.drawio  ← AWS infra diagram
│   └── cicd-pipeline.drawio                ← CI/CD flow diagram
│
├── 🏗️ terraform-aws-modules/       ← Reusable Terraform modules
│   ├── vpc/                        ← Network infrastructure
│   ├── eks/                        ← Kubernetes cluster
│   ├── ecr/                        ← Container registry
│   ├── iam/                        ← Identity & access
│   ├── acm/                        ← SSL certificates
│   └── route53/                    ← DNS management
│
├── ☁️ aws-platform-infra/          ← Environment-specific Terraform
│   ├── terraform/environments/dev/
│   ├── terraform/environments/prod/
│   └── Jenkinsfile                 ← Infra CI/CD pipeline
│
├── ☸️ gitops-eks-platform/         ← ArgoCD GitOps configuration
│   ├── bootstrap/                  ← ArgoCD installation
│   ├── apps/                       ← App-of-Apps definitions
│   ├── platform-services/          ← Platform tooling (monitoring, etc.)
│   └── environments/               ← Dev/Prod values
│
├── 🤖 llmops-rag-gateway/          ← LLM + RAG API service
│   ├── app/                        ← FastAPI Python application
│   ├── helm/                       ← Kubernetes Helm chart
│   ├── k8s/                        ← Raw manifests + monitoring
│   └── tests/                      ← Unit + integration tests
│
├── 🟢 app-microservice-demo/       ← Node.js microservice demo
│   ├── src/                        ← Express.js application
│   ├── helm/                       ← Kubernetes Helm chart
│   └── tests/                      ← Unit + integration tests
│
└── 📊 sre-observability-stack/     ← SRE tooling & practices
    ├── monitoring/                 ← Prometheus + Grafana config
    ├── load-tests/                 ← k6 performance tests
    └── runbooks/                   ← Incident response playbooks
```

---

## 🚀 Quick Start

See [DEPLOYMENT.md](DEPLOYMENT.md) for full step-by-step deployment instructions.

```bash
# 1. Bootstrap AWS infrastructure
cd aws-platform-infra/terraform/environments/dev
terraform init && terraform apply

# 2. Install ArgoCD
kubectl apply -k gitops-eks-platform/bootstrap/

# 3. Deploy all apps via GitOps
kubectl apply -f gitops-eks-platform/apps/app-of-apps.yaml

# 4. All services deploy automatically via ArgoCD 🎉
```
