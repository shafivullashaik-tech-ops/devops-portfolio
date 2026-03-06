# AWS Load Balancer Controller

Enables ALB/NLB creation via Kubernetes Ingress resources.

## Installation

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f values.yaml
```

## Prerequisites

1. IAM role for service account (IRSA) created via Terraform
2. Update values.yaml with:
   - AWS Account ID
   - EKS Cluster Name

## Usage with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/id
spec:
  ingressClassName: alb
  rules:
    - host: demo.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: demo-app
                port:
                  number: 3000
```

## Common Annotations

- `alb.ingress.kubernetes.io/scheme`: internet-facing or internal
- `alb.ingress.kubernetes.io/target-type`: ip or instance
- `alb.ingress.kubernetes.io/certificate-arn`: ACM certificate ARN
- `alb.ingress.kubernetes.io/ssl-redirect`: '443' for HTTPS redirect
- `alb.ingress.kubernetes.io/healthcheck-path`: /health
- `alb.ingress.kubernetes.io/wafv2-acl-arn`: WAF ACL ARN

## Verification

```bash
# Check controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Check created ALBs
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].LoadBalancerArn'
```
