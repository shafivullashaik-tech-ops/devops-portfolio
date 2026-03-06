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


## External Traffic Flow

Complete request path from internet to application:

```
┌─────────────┐
│   Internet  │
│    User     │
└──────┬──────┘
       │ HTTPS request (demo.example.com)
       ▼
┌──────────────────────────────────────┐
│         Route 53 (DNS)               │
│  • Resolves domain to ALB            │
│  • Health checks                     │
│  • Failover policies                 │
└──────┬───────────────────────────────┘
       │ Routed to ALB DNS
       ▼
┌──────────────────────────────────────┐
│  Application Load Balancer (ALB)     │
│  • SSL/TLS termination (ACM cert)    │
│  • WAF protection                    │
│  • L7 routing                        │
│  • Health checks to targets          │
└──────┬───────────────────────────────┘
       │ HTTP to targets
       ▼
┌──────────────────────────────────────┐
│  AWS Load Balancer Controller        │
│  • Manages ALB via Ingress           │
│  • Target registration               │
│  • Health monitoring                 │
└──────┬───────────────────────────────┘
       │ Routes to service
       ▼
┌──────────────────────────────────────┐
│  Kubernetes Ingress Resource         │
│  • Path-based routing                │
│  • Host-based routing                │
│  • Backend service mapping           │
└──────┬───────────────────────────────┘
       │ To ClusterIP service
       ▼
┌──────────────────────────────────────┐
│  Kubernetes Service (ClusterIP)      │
│  • Load balancing across pods        │
│  • Service discovery                 │
│  • Internal DNS (demo-app.default)   │
└──────┬───────────────────────────────┘
       │ To pod endpoint
       ▼
┌──────────────────────────────────────┐
│  Application Pod                     │
│  • demo-app container                │
│  • Health checks (/health, /ready)   │
│  • Metrics endpoint (/metrics)       │
└──────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Purpose | Technology |
|-------|---------|------------|
| DNS | Domain resolution, health checks, failover | Route 53 |
| Load Balancer | SSL termination, WAF, L7 routing | ALB |
| Controller | ALB lifecycle, target management | AWS LB Controller |
| Ingress | Path/host routing, annotations | Kubernetes Ingress |
| Service | Pod load balancing, discovery | Kubernetes Service |
| Pod | Application logic | Container (Node.js) |

### Traffic Flow Examples

**Example 1: HTTPS Request**
```
https://demo.example.com/api/items
  → Route 53 resolves to ALB
  → ALB terminates SSL with ACM certificate
  → ALB forwards HTTP to target (pod IP)
  → Ingress routes /api/* to demo-app service
  → Service load balances to pod
  → Pod handles request
```

**Example 2: Health Check**
```
ALB health check every 15s
  → HTTP GET /health to pod IP
  → Pod responds 200 OK
  → ALB marks target healthy
  → Route 53 health check to ALB DNS
  → Route 53 marks endpoint healthy
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

## DNS and SSL/TLS Setup

### Route 53 Configuration

**Hosted Zone:**
- Domain: `example.com`
- Name servers delegated from domain registrar
- Records managed via Terraform

**A Record (Alias):**
```
demo.example.com → ALB DNS name
  Type: A (Alias)
  Target: dualstack.k8s-default-demoapp-xxxx.us-east-1.elb.amazonaws.com
  Evaluate target health: Yes
```

**Health Checks:**
- Protocol: HTTPS
- Path: /health
- Interval: 30 seconds
- Failure threshold: 3
- CloudWatch alarm on failure

### SSL/TLS Certificates (ACM)

**Certificate Request:**
```
Primary domain: demo.example.com
SANs: *.demo.example.com, api.demo.example.com
Validation: DNS (automatic via Route 53)
Auto-renewal: Yes (before expiration)
```

**DNS Validation Records:**
ACM creates CNAME records in Route 53:
```
_xxxxx.demo.example.com → _xxxxx.acm-validations.aws
```

**Certificate Attachment:**
- Attached to ALB listener (port 443)
- Managed by AWS Load Balancer Controller via Ingress annotation
- No certificate handling in application pod

### Multi-Region Setup (Optional)

For high availability across regions:

```
┌─────────────┐
│  Route 53   │
│             │
│  Failover   │
│  Policy     │
└──┬───────┬──┘
   │       │
   │       └──────────────┐
   │                      │
   ▼                      ▼
┌──────────┐         ┌──────────┐
│ us-east-1│         │ eu-west-1│
│   ALB    │         │   ALB    │
└────┬─────┘         └────┬─────┘
     │                    │
     ▼                    ▼
   EKS Cluster       EKS Cluster
```

### Domain Setup Requirements

For complete setup, you need:

1. **Domain Name** (~$12/year from Route 53 or other registrar)
2. **Hosted Zone in Route 53** (~$0.50/month)
3. **ACM Certificate** (Free)
4. **ALB** (Created automatically by Ingress, ~$16/month)

**Note:** For portfolio/demo purposes without a real domain:
- Use ALB DNS directly (ugly but works)
- Use self-signed certificate
- Document "would use Route 53 + ACM in production"
