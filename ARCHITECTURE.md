# Architecture Overview

## High-Level Architecture

```
┌─────────────┐
│  Developer  │
└──────┬──────┘
       │ git push
       ▼
┌─────────────────────────────────────────────────┐
│                   GitHub                         │
└──────┬──────────────────────────────────────────┘
       │ webhook
       ▼
┌─────────────────────────────────────────────────┐
│            CI Pipeline (Jenkins)                 │
│  Build → Test → Scan → Push ECR → Update Git    │
└──────┬──────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│             GitOps Repository                    │
└──────┬──────────────────────────────────────────┘
       │ ArgoCD monitors
       ▼
┌─────────────────────────────────────────────────┐
│          CD Pipeline (ArgoCD)                    │
│  Detect → Sync → Deploy → Rollout               │
└──────┬──────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│              Amazon EKS Cluster                  │
│  ┌─────────────────────────────────────────┐   │
│  │ Control Plane (AWS Managed)             │   │
│  └─────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────┐   │
│  │ Worker Nodes                            │   │
│  │  • Application Pods                     │   │
│  │  • ArgoCD                               │   │
│  │  • Monitoring (Prometheus/Grafana)      │   │
│  │  • Ingress                              │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## AWS Network Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                        AWS VPC (10.0.0.0/16)                   │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │            Public Subnets (10.0.1.0/24, 10.0.2.0/24)    │ │
│  │                                                          │ │
│  │  ┌──────────────┐    ┌──────────────┐                  │ │
│  │  │ NAT Gateway  │    │ Load Balancer│                  │ │
│  │  │   (AZ-a)     │    │              │                  │ │
│  │  └──────────────┘    └──────────────┘                  │ │
│  │                                                          │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │          Private Subnets (10.0.10.0/24, 10.0.11.0/24)   │ │
│  │                                                          │ │
│  │  ┌──────────────┐    ┌──────────────┐                  │ │
│  │  │  EKS Nodes   │    │  EKS Nodes   │                  │ │
│  │  │   (AZ-a)     │    │   (AZ-b)     │                  │ │
│  │  └──────────────┘    └──────────────┘                  │ │
│  │                                                          │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

## CI/CD Flow

### Continuous Integration (Jenkins)
1. Webhook triggers Jenkins on Git push
2. Checkout source code
3. Build Docker image (multi-stage)
4. Run unit and integration tests
5. Security scanning (Trivy, npm audit)
6. Push image to ECR
7. Update GitOps repository with new image tag

### Continuous Deployment (ArgoCD)
1. ArgoCD detects change in GitOps repository
2. Compares desired state (Git) vs actual state (cluster)
3. Syncs differences to cluster
4. Deploys using configured strategy (rolling/canary)
5. Monitors health and automatically rolls back on failure

## Security Architecture

### IAM Roles for Service Accounts (IRSA)
```
EKS Pod → Service Account → IAM Role → AWS Service
         (annotated)        (via OIDC)  (S3, ECR, etc.)
```

**Benefits:**
- No hardcoded credentials
- Temporary credentials via STS
- Fine-grained permissions per pod
- Audit trail via CloudTrail

### Network Security
- Private subnets for worker nodes
- Security groups restrict traffic
- Network policies in Kubernetes
- TLS for inter-service communication

## Observability Stack

### Metrics (Prometheus)
- Application metrics (/metrics endpoint)
- Infrastructure metrics (node, pod, container)
- Custom business metrics
- SLO tracking

### Logs (CloudWatch)
- Structured JSON logs
- FluentBit for log collection
- Centralized log aggregation
- Query and analysis

### Dashboards (Grafana)
- Request rate, error rate, duration (RED)
- Infrastructure health
- Application performance
- Business KPIs

## GitOps Pattern

### Principles
- Git as single source of truth
- Declarative configuration
- Automatic synchronization
- Pull-based deployment

### Environment Structure
```
gitops-eks-platform/
├── apps/
│   └── app-of-apps.yaml          # Manages all applications
├── environments/
│   ├── dev/
│   │   └── values.yaml           # Dev configuration
│   └── prod/
│       └── values.yaml           # Prod configuration
└── bootstrap/
    └── argocd-install.yaml       # ArgoCD installation
```

## Infrastructure as Code

### Terraform Module Pattern
```
terraform-aws-modules/            # Reusable modules
├── vpc/
├── eks/
└── ecr/

aws-platform-infra/               # Module consumers
└── terraform/
    └── environments/
        ├── dev/
        └── prod/
```

### State Management
- Remote backend (S3 + DynamoDB)
- State locking prevents concurrent modifications
- Versioned state files
- Encrypted at rest

## Scaling Strategy

### Horizontal Pod Autoscaling
- CPU-based scaling
- Memory-based scaling
- Custom metrics scaling

### Cluster Autoscaling
- Node group auto-scaling
- Scale down idle nodes
- Right-size based on workload

## Disaster Recovery

### Recovery Time Objective (RTO)
- Infrastructure rebuild: ~30 minutes (via Terraform)
- Application deployment: ~5 minutes (via ArgoCD)
- Total RTO: ~35 minutes

### Recovery Point Objective (RPO)
- Git provides point-in-time recovery
- ECR images are immutable and versioned
- Terraform state is versioned in S3
