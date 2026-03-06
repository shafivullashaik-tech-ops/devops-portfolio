# Terraform AWS Modules - Reusable Infrastructure Components

This repository contains enterprise-grade, reusable Terraform modules for AWS infrastructure. These modules follow Terraform best practices and can be consumed by any project.

## 🎯 Design Philosophy

- **Reusable**: Modules work across multiple projects and environments
- **Composable**: Modules can be combined to build complex infrastructure
- **Tested**: Each module includes examples and is tested
- **Documented**: Clear README with inputs, outputs, and examples
- **Versioned**: Use Git tags for version management
- **Secure by Default**: Security best practices baked in

## 📦 Available Modules

| Module | Description | Version | Status |
|--------|-------------|---------|--------|
| [vpc](#vpc-module) | Production-ready VPC with public/private subnets | v1.0.0 | ✅ Stable |
| [eks](#eks-module) | EKS cluster with IRSA and managed node groups | v1.0.0 | ✅ Stable |
| [ecr](#ecr-module) | ECR repositories with lifecycle policies | v1.0.0 | ✅ Stable |
| [jenkins](#jenkins-module) | Jenkins server on EC2 with Docker | v1.0.0 | ✅ Stable |
| [iam](#iam-module) | IAM roles for IRSA and service accounts | v1.0.0 | ✅ Stable |
| [monitoring](#monitoring-module) | Prometheus + Grafana stack | v1.0.0 | 🚧 Beta |

## 🚀 Quick Start

### Using Modules in Your Project

```hcl
# In your project's main.tf
module "vpc" {
  source = "git::https://github.com/your-username/terraform-aws-modules.git//vpc?ref=v1.0.0"

  vpc_cidr     = "10.0.0.0/16"
  cluster_name = "my-eks-cluster"
  environment  = "dev"

  tags = {
    Project = "my-project"
    Owner   = "platform-team"
  }
}

module "eks" {
  source = "git::https://github.com/your-username/terraform-aws-modules.git//eks?ref=v1.0.0"

  cluster_name    = "my-eks-cluster"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  node_instance_type = "t3.medium"
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 5
}
```

## 📚 Module Documentation

### VPC Module

Creates a production-ready VPC with:
- Configurable CIDR blocks
- Public and private subnets across multiple AZs
- Internet Gateway and NAT Gateways
- Proper route tables
- VPC Flow Logs
- Tags for EKS integration

**Example Usage**:
```hcl
module "vpc" {
  source = "../terraform-aws-modules/vpc"

  vpc_cidr     = "10.0.0.0/16"
  cluster_name = "portfolio-eks"
  environment  = "dev"

  # Optional: Customize subnet CIDRs
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  # Optional: Single NAT for cost savings
  single_nat_gateway = true

  tags = {
    Terraform = "true"
    Project   = "portfolio"
  }
}
```

**Outputs**:
- `vpc_id`: VPC ID
- `private_subnet_ids`: List of private subnet IDs
- `public_subnet_ids`: List of public subnet IDs
- `nat_gateway_ips`: NAT Gateway Elastic IPs

---

### EKS Module

Creates an EKS cluster with:
- Managed node groups
- IRSA (IAM Roles for Service Accounts) enabled
- OIDC provider configured
- Cluster add-ons (CoreDNS, kube-proxy, VPC CNI)
- CloudWatch logging
- Security groups properly configured

**Example Usage**:
```hcl
module "eks" {
  source = "../terraform-aws-modules/eks"

  cluster_name       = "portfolio-eks-dev"
  kubernetes_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # Node group configuration
  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      disk_size      = 30
    }
  }

  # Enable add-ons
  enable_cluster_autoscaler = true
  enable_metrics_server     = true

  tags = {
    Environment = "dev"
  }
}
```

**Outputs**:
- `cluster_id`: EKS cluster name
- `cluster_endpoint`: EKS API endpoint
- `cluster_certificate_authority_data`: CA cert for kubectl
- `oidc_provider_arn`: OIDC provider ARN for IRSA
- `node_security_group_id`: Security group ID for worker nodes

---

### ECR Module

Creates ECR repositories with:
- Scan on push enabled
- Lifecycle policies (retain last N images)
- Encryption at rest
- Cross-region replication (optional)

**Example Usage**:
```hcl
module "ecr" {
  source = "../terraform-aws-modules/ecr"

  repository_name        = "demo-app"
  image_retention_count  = 10
  scan_on_push           = true
  encryption_type        = "AES256"

  # Optional: Allow specific IAM roles to pull
  allowed_pull_principals = [
    "arn:aws:iam::123456789:role/jenkins-role"
  ]

  tags = {
    Application = "demo-app"
  }
}
```

**Outputs**:
- `repository_url`: Full ECR repository URL
- `repository_arn`: ARN of the repository
- `repository_name`: Name of the repository

---

### Jenkins Module

Creates a Jenkins server with:
- EC2 instance with Docker pre-installed
- IAM instance profile for AWS access
- Security group allowing ports 8080 and 22
- EBS volume for Jenkins home
- User data script for initialization
- Elastic IP for consistent access

**Example Usage**:
```hcl
module "jenkins" {
  source = "../terraform-aws-modules/jenkins"

  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  instance_type     = "t3.small"
  key_name          = "my-key-pair"

  # IAM permissions
  ecr_repository_arns = [module.ecr.repository_arn]
  eks_cluster_name    = module.eks.cluster_id

  # Optional: Custom plugins
  jenkins_plugins = [
    "docker-workflow:1.29",
    "kubernetes:3900.va_dce992317b_4",
    "aws-credentials:1.32"
  ]

  allowed_cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production!

  tags = {
    Name = "jenkins-server"
  }
}
```

**Outputs**:
- `jenkins_public_ip`: Public IP address
- `jenkins_url`: Full Jenkins URL
- `jenkins_instance_id`: EC2 instance ID
- `jenkins_security_group_id`: Security group ID

---

### IAM Module

Creates IAM roles for:
- IRSA (IAM Roles for Service Accounts)
- Service-specific permissions
- Cross-account access (optional)

**Example Usage**:
```hcl
module "iam" {
  source = "../terraform-aws-modules/iam"

  cluster_name       = module.eks.cluster_id
  oidc_provider_arn  = module.eks.oidc_provider_arn

  # Create IRSA role for ArgoCD
  create_argocd_role = true
  argocd_namespace   = "argocd"

  # Create IRSA role for application
  create_app_role = true
  app_namespace   = "default"
  app_s3_buckets  = ["my-app-bucket"]

  tags = {
    ManagedBy = "terraform"
  }
}
```

**Outputs**:
- `argocd_role_arn`: ARN for ArgoCD IRSA role
- `app_role_arn`: ARN for application IRSA role
- `jenkins_role_arn`: ARN for Jenkins EC2 role

---

## 🏗️ Module Development Guidelines

### Structure
Each module follows this structure:
```
module-name/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── versions.tf       # Terraform and provider version constraints
├── README.md         # Module documentation
└── examples/         # Usage examples
    └── basic/
        ├── main.tf
        └── README.md
```

### Naming Conventions
- **Resources**: Use descriptive names with prefixes
  ```hcl
  resource "aws_vpc" "main" { ... }  # Good
  resource "aws_vpc" "v" { ... }     # Bad
  ```
- **Variables**: Use clear, descriptive names
  ```hcl
  variable "cluster_name" { ... }    # Good
  variable "cn" { ... }              # Bad
  ```
- **Tags**: Include Name, Environment, Terraform tags

### Variable Validation
Always include validation where possible:
```hcl
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### Outputs
Document outputs clearly:
```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}
```

## 🧪 Testing

Each module should be tested:

1. **Syntax Check**:
   ```bash
   terraform fmt -check -recursive
   terraform validate
   ```

2. **Static Analysis**:
   ```bash
   tflint
   checkov -d .
   ```

3. **Integration Testing**:
   ```bash
   cd examples/basic
   terraform init
   terraform plan
   terraform apply -auto-approve
   # Run tests
   terraform destroy -auto-approve
   ```

## 📋 Version Management

### Tagging Strategy
```bash
# Tag a stable release
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Consume in projects
module "vpc" {
  source = "git::https://github.com/user/terraform-aws-modules.git//vpc?ref=v1.0.0"
}
```

### Semantic Versioning
- **v1.0.0**: Major version (breaking changes)
- **v1.1.0**: Minor version (new features, backward compatible)
- **v1.1.1**: Patch version (bug fixes)

## 🔒 Security Best Practices

### 1. Least Privilege
All IAM roles follow least privilege principle:
```hcl
# ❌ Don't do this
policy = "arn:aws:iam::aws:policy/AdministratorAccess"

# ✅ Do this
policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect   = "Allow"
    Action   = ["ecr:PutImage", "ecr:GetAuthorizationToken"]
    Resource = "*"
  }]
})
```

### 2. Encryption by Default
```hcl
# EBS volumes encrypted
ebs_block_device {
  encrypted   = true
  kms_key_id  = var.kms_key_id
}

# S3 buckets encrypted
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
```

### 3. No Hardcoded Secrets
```hcl
# ❌ Don't do this
environment = {
  API_KEY = "abc123"
}

# ✅ Do this
environment = {
  API_KEY_SECRET_ARN = aws_secretsmanager_secret.api_key.arn
}
```

## 📊 Cost Optimization

### VPC Module
- Single NAT Gateway for dev: Saves $32/month
- VPC endpoints for AWS services: Reduces data transfer costs

### EKS Module
- Spot instances support: Save up to 70%
- Cluster autoscaler: Scale down when idle
- Right-sized instances: Don't over-provision

### ECR Module
- Lifecycle policies: Auto-delete old images
- Cross-region replication: Only when needed

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-module`)
3. Follow module development guidelines
4. Add tests and documentation
5. Submit a pull request

## 📖 Additional Resources

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Module Registry](https://registry.terraform.io/)

---

**Maintained by**: DevOps Team
**License**: MIT
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: >= 5.0
