# Portfolio Architecture - Enterprise DevOps Platform

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DEVELOPER WORKFLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ git push
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                   GITHUB                                     │
│                          (Source Code Repositories)                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ webhook
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CI PIPELINE (JENKINS)                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Checkout │→ │  Build   │→ │   Test   │→ │   Scan   │→ │ Push ECR │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
│       │                                                          │           │
│       │ EC2 Instance (Jenkins)                                  │           │
│       │ IAM Instance Profile (No hardcoded keys!)               │           │
└───────┼──────────────────────────────────────────────────────────┼───────────┘
        │                                                          │
        │                                                          ▼
        │                                            ┌─────────────────────────┐
        │                                            │      AWS ECR            │
        │                                            │ (Container Registry)    │
        │                                            └─────────────────────────┘
        │                                                          │
        │ Update image tag                                         │
        ▼                                                          │
┌─────────────────────────────────────────────────────────────────┴───────────┐
│                           GITOPS REPOSITORY                                  │
│              (Kubernetes Manifests + Helm Charts + Kustomize)                │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ ArgoCD monitors
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CD PIPELINE (ARGOCD on EKS)                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │  Detect  │→ │   Sync   │→ │  Deploy  │→ │ Rollout  │                   │
│  │  Change  │  │  State   │  │  to EKS  │  │ Strategy │                   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AMAZON EKS CLUSTER                                   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        CONTROL PLANE (AWS Managed)                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────── WORKER NODES ──────────────────────────┐   │
│  │                                                                       │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │   │
│  │  │   APP PODS      │  │  ARGOCD PODS    │  │  MONITORING     │    │   │
│  │  │  (Demo App)     │  │  (GitOps Ctrl)  │  │  (Prometheus)   │    │   │
│  │  │                 │  │                 │  │  (Grafana)      │    │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘    │   │
│  │                                                                       │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │   │
│  │  │ ARGO ROLLOUTS   │  │   INGRESS       │  │     LOGGING     │    │   │
│  │  │ (Canary/Blue-   │  │   NGINX         │  │   FluentBit     │    │   │
│  │  │  Green Deploy)  │  │                 │  │                 │    │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘    │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          OBSERVABILITY LAYER                                 │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Prometheus  │  │   Grafana    │  │  CloudWatch  │  │   X-Ray      │  │
│  │   (Metrics)  │  │ (Dashboards) │  │    (Logs)    │  │  (Tracing)   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 🗂️ Repository Structure (Microservices Pattern)

```
portfolio/
│
├── ARCHITECTURE.md                          # ← This file
├── README.md                                # ← Main overview
│
├── terraform-aws-modules/                   # ← Reusable Terraform Modules (Repo 1)
│   ├── vpc/                                 # │  Enterprise pattern: Separate modules repo
│   │   ├── main.tf                          # │  These are version-tagged and reusable
│   │   ├── variables.tf                     # │  across multiple projects
│   │   ├── outputs.tf                       # │
│   │   └── README.md                        # │  Interview Point: "I built reusable
│   ├── eks/                                 # │  infrastructure modules that can be
│   │   ├── main.tf                          # │  consumed by any project, following
│   │   ├── variables.tf                     # │  DRY principles and Terraform best
│   │   ├── outputs.tf                       # │  practices"
│   │   └── README.md                        # │
│   ├── ecr/                                 # │
│   ├── jenkins/                             # │
│   ├── iam/                                 # │
│   └── monitoring/                          # ↓
│
├── aws-platform-infra/                      # ← Infrastructure Consumer (Repo 2)
│   ├── terraform/                           # │  Only calls modules - NO direct resources!
│   │   ├── environments/                    # │
│   │   │   ├── dev/                         # │  Interview Point: "The platform repo
│   │   │   │   ├── main.tf                  # │  consumes modules and only defines
│   │   │   │   ├── terraform.tfvars         # │  environment-specific variables.
│   │   │   │   └── backend.tf               # │  This separation allows teams to use
│   │   │   └── prod/                        # │  tested modules without worrying
│   │   │       ├── main.tf                  # │  about infrastructure details"
│   │   │       ├── terraform.tfvars         # │
│   │   │       └── backend.tf               # │
│   │   └── shared/                          # │
│   │       └── backend-setup/               # │
│   ├── jenkins/                             # │
│   │   ├── plugins.txt                      # │
│   │   └── jenkins-casc.yaml                # │
│   └── scripts/                             # ↓
│       ├── setup-kubectl.sh
│       └── get-jenkins-info.sh
│
├── gitops-eks-platform/                     # ← GitOps Configuration (Repo 3)
│   ├── bootstrap/                           # │  ArgoCD bootstrap
│   │   └── argocd-install.yaml              # │
│   ├── apps/                                # │
│   │   ├── app-of-apps.yaml                 # │  Interview Point: "I use ArgoCD's
│   │   └── platform-apps.yaml               # │  app-of-apps pattern for managing
│   ├── environments/                        # │  all cluster applications. Each
│   │   ├── dev/                             # │  environment has its own config,
│   │   │   ├── kustomization.yaml           # │  and ArgoCD automatically syncs
│   │   │   └── values.yaml                  # │  Git state to cluster state"
│   │   └── prod/                            # │
│   │       ├── kustomization.yaml           # │
│   │       └── values.yaml                  # │
│   └── platform-services/                   # │
│       ├── monitoring/                      # │
│       │   ├── prometheus/                  # │
│       │   └── grafana/                     # │
│       ├── ingress-nginx/                   # │
│       └── cert-manager/                    # ↓
│
└── app-microservice-demo/                   # ← Sample Application (Repo 4)
    ├── src/                                 # │  Node.js/Express API
    │   ├── app.js                           # │
    │   ├── routes/                          # │
    │   └── middleware/                      # │
    ├── tests/                               # │  Interview Point: "The app has
    │   ├── unit/                            # │  health, metrics, and readiness
    │   └── integration/                     # │  endpoints for Kubernetes probes.
    ├── helm/                                # │  The Helm chart is environment-
    │   ├── Chart.yaml                       # │  aware and works with GitOps"
    │   ├── values.yaml                      # │
    │   └── templates/                       # │
    │       ├── deployment.yaml              # │
    │       ├── service.yaml                 # │
    │       ├── ingress.yaml                 # │
    │       └── rollout.yaml                 # │
    ├── Dockerfile                           # │  Multi-stage build
    ├── Jenkinsfile                          # │  Declarative pipeline
    └── .dockerignore                        # ↓
```

## 🔄 CI/CD Flow (Interview Explanation)

### Phase 1: Continuous Integration (Jenkins)
```
Developer commits code
         ↓
GitHub webhook triggers Jenkins
         ↓
┌─────────────────────────────────────┐
│ Stage 1: Checkout                   │
│ - Clone repository                  │
│ - Check out specific branch         │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ Stage 2: Build                      │
│ - npm install                       │
│ - Build Docker image                │
│ - Tag with git commit SHA           │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ Stage 3: Test                       │
│ - Run unit tests (Jest)             │
│ - Run integration tests             │
│ - Code coverage report              │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ Stage 4: Security Scan              │
│ - Trivy: Scan for vulnerabilities   │
│ - Checkov: Scan Dockerfile          │
│ - OWASP: Dependency check           │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ Stage 5: Push to ECR                │
│ - Authenticate using IRSA           │
│ - Push image to ECR                 │
│ - Tag as latest + commit SHA        │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ Stage 6: Update GitOps Repo         │
│ - Clone gitops repo                 │
│ - Update image tag in values.yaml   │
│ - Commit and push                   │
│ - CI STOPS HERE (no kubectl apply) │
└─────────────────────────────────────┘
```

### Phase 2: Continuous Deployment (ArgoCD)
```
GitOps repo updated by Jenkins
         ↓
┌─────────────────────────────────────┐
│ ArgoCD Detects Change               │
│ - Polls Git every 3 minutes         │
│ - Or webhook for instant sync       │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ ArgoCD Syncs to EKS                 │
│ - Helm template rendering           │
│ - Apply Kubernetes manifests        │
│ - Health checks                     │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ Argo Rollouts (Progressive Deploy) │
│ - Canary: 20% → 50% → 100%         │
│ - Monitor metrics during rollout    │
│ - Auto-rollback on failure          │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ Application Running                 │
│ - Prometheus scrapes metrics        │
│ - Grafana visualizes                │
│ - CloudWatch logs aggregated        │
└─────────────────────────────────────┘
```

## 🌐 AWS Network Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Region (us-east-1)                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                            VPC (10.0.0.0/16)                            │ │
│  │                                                                          │ │
│  │  ┌─────────────────────┐              ┌─────────────────────┐          │ │
│  │  │   Availability      │              │   Availability      │          │ │
│  │  │   Zone A            │              │   Zone B            │          │ │
│  │  │                     │              │                     │          │ │
│  │  │  ┌───────────────┐  │              │  ┌───────────────┐ │          │ │
│  │  │  │ Public Subnet │  │              │  │ Public Subnet │ │          │ │
│  │  │  │ 10.0.1.0/24   │  │              │  │ 10.0.2.0/24   │ │          │ │
│  │  │  │               │  │              │  │               │ │          │ │
│  │  │  │ ┌───────────┐ │  │              │  │ ┌───────────┐ │ │          │ │
│  │  │  │ │  Jenkins  │ │  │              │  │ │ NAT       │ │ │          │ │
│  │  │  │ │  EC2      │ │  │              │  │ │ Gateway   │ │ │          │ │
│  │  │  │ └───────────┘ │  │              │  │ └───────────┘ │ │          │ │
│  │  │  └───────┬───────┘  │              │  └───────┬───────┘ │          │ │
│  │  │          │           │              │          │         │          │ │
│  │  │  ┌───────▼───────┐  │              │  ┌───────▼───────┐ │          │ │
│  │  │  │Private Subnet │  │              │  │Private Subnet │ │          │ │
│  │  │  │ 10.0.10.0/24  │  │              │  │ 10.0.11.0/24  │ │          │ │
│  │  │  │               │  │              │  │               │ │          │ │
│  │  │  │ ┌───────────┐ │  │              │  │ ┌───────────┐ │ │          │ │
│  │  │  │ │EKS Worker │ │  │              │  │ │EKS Worker │ │ │          │ │
│  │  │  │ │  Node 1   │ │  │              │  │ │  Node 2   │ │ │          │ │
│  │  │  │ └───────────┘ │  │              │  │ └───────────┘ │ │          │ │
│  │  │  └───────────────┘  │              │  └───────────────┘ │          │ │
│  │  └─────────────────────┘              └─────────────────────┘          │ │
│  │                                                                          │ │
│  └────────┬──────────────────────────────────────────────────┬────────────┘ │
│           │                                                   │              │
│  ┌────────▼────────┐                              ┌──────────▼──────────┐   │
│  │ Internet Gateway│                              │  EKS Control Plane  │   │
│  └─────────────────┘                              │   (AWS Managed)     │   │
│                                                    └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

External Services:
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│     ECR     │  │ CloudWatch  │  │     S3      │  │  DynamoDB   │
│  (Images)   │  │   (Logs)    │  │  (TF State) │  │  (TF Lock)  │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
```

## 🔐 Security Architecture (Interview Key Points)

### 1. No Hardcoded Credentials
```
❌ BAD (Don't do this):
  - AWS keys in Jenkins credentials
  - Secrets in environment variables
  - Passwords in Git

✅ GOOD (What we do):
  - Jenkins EC2: IAM Instance Profile
  - EKS Pods: IRSA (IAM Roles for Service Accounts)
  - Secrets: AWS Secrets Manager + External Secrets Operator
```

### 2. Network Segmentation
```
Internet
    ↓
Internet Gateway (Public only)
    ↓
Public Subnet: Jenkins, NAT Gateway
    ↓
NAT Gateway
    ↓
Private Subnet: EKS Worker Nodes, Application Pods
    ↓
VPC Endpoints: ECR, S3, CloudWatch (no internet egress)
```

### 3. Least Privilege IAM
```
Jenkins EC2 Role:
  - ecr:PutImage, ecr:GetAuthorizationToken
  - eks:DescribeCluster (read-only)
  - NO admin permissions

ArgoCD Pod Role (IRSA):
  - Limited to namespace operations
  - Can't modify cluster-wide resources

App Pod Role (IRSA):
  - Only access to specific S3 buckets
  - Only specific DynamoDB tables
```

## 📊 Monitoring & Observability

### Metrics Stack
```
Application → Prometheus (scrape /metrics endpoint every 15s)
                ↓
            Time-series DB
                ↓
            Grafana Dashboards
                ↓
            Alerts (Slack/PagerDuty)
```

### Key Metrics
- **RED Method**: Rate, Errors, Duration
- **Resource**: CPU, Memory, Disk, Network
- **Business**: Active users, API calls, revenue

### Logs Stack
```
Application logs → FluentBit (sidecar) → CloudWatch Logs → Insights queries
```

## 🎯 Interview Talking Points

### Why this architecture?
"I designed this to mirror production environments at scale-ups and enterprises. The separation of CI (Jenkins) and CD (ArgoCD) follows GitOps principles where Git is the single source of truth. This enables better auditability, easier rollbacks, and separation of concerns between build and deploy responsibilities."

### Why separate modules repo?
"The terraform-aws-modules repository acts as a reusable module library. Just like how companies maintain internal Terraform Registry, this allows any project to consume tested, versioned modules. It follows DRY principles and makes infrastructure changes safer through centralized testing."

### Why GitOps over traditional CD?
"Traditional CD tools push changes (Jenkins kubectl apply). GitOps uses a pull model where ArgoCD continuously reconciles cluster state with Git. This means:
- Git is the source of truth (better audit trail)
- Easier rollbacks (git revert)
- Drift detection (cluster differs from Git)
- Better security (no external kubectl access needed)"

### How do you handle different environments?
"I use Kustomize overlays within the GitOps repo. Each environment (dev/staging/prod) has its own values.yaml with different:
- Replica counts
- Resource limits
- Ingress domains
- Feature flags
- But they share the same base manifests"

### How do you ensure zero-downtime deployments?
"Argo Rollouts provides canary deployments. When a new version deploys:
1. Route 20% traffic to new version
2. Monitor metrics for 5 minutes
3. If success: increase to 50%, then 100%
4. If failure: automatic rollback to previous version
5. Health checks and readiness probes prevent bad pods from receiving traffic"

### What about secrets management?
"I use External Secrets Operator which syncs AWS Secrets Manager to Kubernetes Secrets. The application never accesses AWS directly. ESO runs with IRSA permissions and regularly syncs secrets. This separates secret storage (AWS) from secret usage (Kubernetes) and provides encryption at rest and in transit."

---

**Next**: See detailed implementation in each repository's README.md
