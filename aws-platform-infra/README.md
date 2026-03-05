# AWS Platform Infrastructure

This repository contains Terraform code to provision the complete AWS infrastructure for the DevOps portfolio platform.

## Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── NAT Gateways
│   ├── Internet Gateway
│   └── Jenkins EC2 Instance
└── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
    ├── EKS Cluster
    │   ├── Control Plane (AWS Managed)
    │   └── Worker Nodes (EC2 Auto Scaling Group)
    └── Application Workloads
```

## What Gets Created

### Networking (VPC Module)
- VPC with CIDR 10.0.0.0/16
- 2 Public subnets across 2 AZs
- 2 Private subnets across 2 AZs
- Internet Gateway
- NAT Gateway (1 for cost savings, can scale to 2)
- Route tables and associations
- VPC Flow Logs to CloudWatch

### EKS Cluster (EKS Module)
- EKS Control Plane (latest Kubernetes version)
- Managed Node Group (2x t3.medium instances)
- IRSA (IAM Roles for Service Accounts) enabled
- Cluster add-ons: CoreDNS, kube-proxy, VPC CNI
- Security groups for control plane and nodes
- CloudWatch logging enabled

### Container Registry (ECR Module)
- ECR repository for application images
- Lifecycle policy (keep last 10 images)
- Scan on push enabled
- Encryption at rest

### Jenkins Server (Jenkins Module)
- EC2 instance (t3.small)
- IAM instance profile with ECR and EKS permissions
- Security group (allow 8080, 22)
- User data script to install Jenkins, Docker, kubectl
- Elastic IP for consistent access

### IAM & Security (IAM Module)
- IRSA roles for ArgoCD, application pods
- Jenkins EC2 role
- ECR pull/push policies
- EKS node IAM role
- Least privilege policies

## Prerequisites

1. **AWS Account** with admin access (for initial setup)
2. **AWS CLI** configured:
   ```bash
   aws configure
   # Enter your Access Key, Secret Key, Region (us-east-1 recommended)
   ```
3. **Terraform** installed (version >= 1.5):
   ```bash
   # macOS
   brew install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```
4. **kubectl** installed:
   ```bash
   # macOS
   brew install kubectl

   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

## Deployment

### Step 1: Configure Backend (Optional but Recommended)

For production use, store Terraform state in S3:

```bash
cd terraform/environments/dev

# Create S3 bucket and DynamoDB table for state locking
aws s3 mb s3://your-terraform-state-bucket-unique-name
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Edit backend.tf to use your bucket name
```

### Step 2: Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

### Step 3: Review Plan

```bash
terraform plan -out=tfplan

# Review the output carefully
# Should show ~40-50 resources to be created
```

### Step 4: Apply Infrastructure

```bash
terraform apply tfplan

# This takes approximately 20-25 minutes
# EKS cluster creation is the longest part (~15 min)
```

### Step 5: Configure kubectl

```bash
# Get kubeconfig for the newly created EKS cluster
aws eks update-kubeconfig --name portfolio-eks-dev --region us-east-1

# Verify connection
kubectl get nodes
# Should show 2 nodes in Ready state
```

### Step 6: Access Jenkins

```bash
# Get Jenkins URL
terraform output jenkins_public_ip

# Get initial admin password
ssh -i ~/.ssh/your-key.pem ec2-user@<jenkins-ip> \
  "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"

# Or use the helper script
cd ../../scripts
./get-jenkins-info.sh
```

## Outputs

After successful deployment, you'll get:

```hcl
vpc_id                  = "vpc-xxxxx"
eks_cluster_name        = "portfolio-eks-dev"
eks_cluster_endpoint    = "https://xxxxx.eks.us-east-1.amazonaws.com"
ecr_repository_url      = "123456789.dkr.ecr.us-east-1.amazonaws.com/demo-app"
jenkins_public_ip       = "54.x.x.x"
jenkins_url             = "http://54.x.x.x:8080"
```

## Module Documentation

### VPC Module (`modules/vpc/`)
Creates a production-ready VPC with public/private subnets, NAT gateways, and proper tagging for EKS.

**Inputs**:
- `vpc_cidr`: CIDR block for VPC (default: 10.0.0.0/16)
- `cluster_name`: EKS cluster name for tagging
- `environment`: Environment name (dev/prod)

**Outputs**:
- `vpc_id`, `private_subnet_ids`, `public_subnet_ids`

### EKS Module (`modules/eks/`)
Creates EKS cluster with managed node groups and IRSA enabled.

**Inputs**:
- `cluster_name`: Name of EKS cluster
- `vpc_id`: VPC ID from VPC module
- `subnet_ids`: Private subnet IDs for worker nodes
- `node_instance_type`: EC2 instance type (default: t3.medium)
- `node_desired_size`: Desired number of nodes (default: 2)

**Outputs**:
- `cluster_id`, `cluster_endpoint`, `cluster_certificate_authority_data`

### ECR Module (`modules/ecr/`)
Creates ECR repositories with lifecycle policies.

**Inputs**:
- `repository_name`: Name of ECR repository
- `image_retention_count`: Number of images to keep (default: 10)

**Outputs**:
- `repository_url`, `repository_arn`

### Jenkins Module (`modules/jenkins/`)
Creates EC2 instance with Jenkins pre-installed.

**Inputs**:
- `vpc_id`: VPC ID
- `subnet_id`: Public subnet ID
- `key_name`: EC2 key pair name
- `instance_type`: Instance type (default: t3.small)

**Outputs**:
- `jenkins_public_ip`, `jenkins_security_group_id`

### IAM Module (`modules/iam/`)
Creates IAM roles and policies with least privilege.

**Inputs**:
- `cluster_name`: EKS cluster name
- `oidc_provider_arn`: OIDC provider ARN from EKS

**Outputs**:
- `jenkins_role_arn`, `argocd_role_arn`, `app_role_arn`

## Environment Configuration

### Dev Environment
- Smaller instance types (t3.small/medium)
- Single NAT Gateway
- Minimal node count (2)
- Relaxed resource limits
- Cost: ~$100-120/month

### Prod Environment (Optional)
- Larger instance types (t3.large)
- Multi-AZ NAT Gateways
- Higher node count (3-5)
- Autoscaling enabled
- Cost: ~$250-300/month

## Maintenance

### Update Kubernetes Version
```bash
# Update cluster version in terraform.tfvars
kubernetes_version = "1.28"

# Apply changes
terraform plan
terraform apply
```

### Scale Node Group
```bash
# Update desired size in terraform.tfvars
node_desired_size = 3

terraform apply
```

### Destroy Infrastructure
```bash
# DANGER: This deletes everything!
terraform destroy

# Cost savings: Run this when not demoing
# Rebuild takes ~25 minutes when needed
```

## Troubleshooting

### Issue: EKS nodes not joining cluster
```bash
# Check IAM role trust relationship
aws iam get-role --role-name portfolio-eks-node-role

# Check security groups
kubectl get nodes  # Should eventually show nodes
```

### Issue: Can't connect to Jenkins
```bash
# Check security group allows your IP
aws ec2 describe-security-groups --group-ids <jenkins-sg-id>

# SSH into Jenkins instance
ssh -i ~/.ssh/your-key.pem ec2-user@<jenkins-ip>
sudo systemctl status jenkins
```

### Issue: Terraform state locked
```bash
# Force unlock (only if previous run crashed)
terraform force-unlock <lock-id>
```

## Cost Optimization

1. **Stop Jenkins when not needed**:
   ```bash
   aws ec2 stop-instances --instance-ids <jenkins-instance-id>
   # Start it back: aws ec2 start-instances --instance-ids <id>
   ```

2. **Use Spot Instances for EKS nodes**:
   - Update node group configuration to use spot instances
   - Save ~70% on compute costs

3. **Delete when not demoing**:
   ```bash
   terraform destroy
   # Costs stop immediately
   # Rebuild anytime with terraform apply
   ```

4. **Single NAT Gateway**:
   - Already configured for dev
   - Trade-off: Single point of failure (acceptable for demos)

## Security Considerations

### Credentials
- ✅ No hardcoded AWS keys in code
- ✅ Using IRSA for pod-level permissions
- ✅ Jenkins uses instance profile (no keys)

### Network Security
- ✅ Private subnets for workloads
- ✅ Security groups with minimal ports
- ✅ VPC Flow Logs enabled

### Encryption
- ✅ EKS secrets encrypted with KMS
- ✅ ECR encryption at rest
- ✅ EBS volumes encrypted

### Improvements for Production
- Enable AWS GuardDuty
- Enable AWS Config rules
- Implement VPC endpoints for AWS services
- Enable AWS WAF for public endpoints
- Implement AWS Secrets Manager

## Next Steps

After infrastructure is deployed:

1. **Configure Jenkins** (see `jenkins/` directory)
2. **Setup ArgoCD** (see `gitops-eks-platform` repo)
3. **Deploy sample app** (see `app-microservice-demo` repo)

---

**Estimated Deployment Time**: 25-30 minutes
**Estimated Monthly Cost**: $100-120 (dev), $250-300 (prod)
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: >= 5.0
