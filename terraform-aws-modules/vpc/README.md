# VPC Terraform Module

Production-ready AWS VPC module with public and private subnets across multiple availability zones.

## Features

- ✅ Multi-AZ deployment for high availability
- ✅ Public subnets for internet-facing resources
- ✅ Private subnets for application workloads
- ✅ NAT Gateways for outbound internet access from private subnets
- ✅ VPC Flow Logs for network monitoring
- ✅ Proper tagging for EKS integration
- ✅ Cost optimization option (single NAT Gateway for dev)

## Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── Internet Gateway → Internet
│   └── NAT Gateways
├── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
│   └── NAT Gateway → Internet Gateway → Internet
└── Route Tables
    ├── Public RT (IGW route)
    └── Private RT (NAT route)
```

## Usage

### Basic Example

```hcl
module "vpc" {
  source = "../terraform-aws-modules/vpc"

  vpc_cidr     = "10.0.0.0/16"
  cluster_name = "my-eks-cluster"
  environment  = "dev"

  tags = {
    Terraform = "true"
    Project   = "portfolio"
  }
}
```

### Production Example (Multi-NAT)

```hcl
module "vpc" {
  source = "../terraform-aws-modules/vpc"

  vpc_cidr     = "10.0.0.0/16"
  cluster_name = "prod-eks-cluster"
  environment  = "prod"

  # Use multiple NAT Gateways for HA
  single_nat_gateway = false

  # Custom subnet CIDRs
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

  # Enable Flow Logs
  enable_flow_logs          = true
  flow_logs_retention_days  = 30

  tags = {
    Terraform   = "true"
    Environment = "prod"
    CostCenter  = "platform"
  }
}
```

### Dev Environment (Cost Optimized)

```hcl
module "vpc" {
  source = "../terraform-aws-modules/vpc"

  vpc_cidr     = "10.0.0.0/16"
  cluster_name = "dev-eks-cluster"
  environment  = "dev"

  # Single NAT Gateway to save costs (~$32/month)
  single_nat_gateway = true

  # Shorter log retention
  flow_logs_retention_days = 7

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_cidr | CIDR block for VPC | string | "10.0.0.0/16" | no |
| cluster_name | Name of EKS cluster | string | - | yes |
| environment | Environment name (dev/staging/prod) | string | - | yes |
| public_subnet_cidrs | CIDR blocks for public subnets | list(string) | ["10.0.1.0/24", "10.0.2.0/24"] | no |
| private_subnet_cidrs | CIDR blocks for private subnets | list(string) | ["10.0.10.0/24", "10.0.11.0/24"] | no |
| single_nat_gateway | Use single NAT Gateway for cost savings | bool | true | no |
| enable_flow_logs | Enable VPC Flow Logs | bool | true | no |
| flow_logs_retention_days | Flow logs retention period | number | 7 | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr | The CIDR block of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| nat_gateway_ids | List of NAT Gateway IDs |
| nat_gateway_ips | List of NAT Gateway Elastic IPs |
| internet_gateway_id | Internet Gateway ID |
| public_route_table_id | Public route table ID |
| private_route_table_ids | List of private route table IDs |
| availability_zones | List of AZs used |

## EKS Integration

This module automatically tags subnets for EKS integration:

- **Public subnets**: Tagged with `kubernetes.io/role/elb=1` for external load balancers
- **Private subnets**: Tagged with `kubernetes.io/role/internal-elb=1` for internal load balancers
- **All subnets**: Tagged with `kubernetes.io/cluster/${cluster_name}=shared`

## Cost Considerations

### Single NAT Gateway (Dev)
- **Cost**: ~$32/month
- **Trade-off**: Single point of failure for outbound internet
- **Use case**: Dev/test environments

### Multi-NAT Gateway (Prod)
- **Cost**: ~$64/month (2 AZs) or ~$96/month (3 AZs)
- **Benefit**: High availability, no single point of failure
- **Use case**: Production environments

### VPC Flow Logs
- **Cost**: ~$0.50/GB ingested + $0.03/GB storage
- **Typical**: ~$5-10/month for small environments
- **Benefit**: Network monitoring, security analysis, compliance

## Security Best Practices

1. **Private Subnets**: Application workloads run in private subnets with no direct internet access
2. **NAT Gateways**: Controlled outbound internet access through NAT
3. **Flow Logs**: Network traffic monitoring for security analysis
4. **Security Groups**: Applied at ENI level (configured per resource, not in VPC module)
5. **Network ACLs**: Default ACLs allow all traffic (can be customized)

## Troubleshooting

### Issue: Resources can't reach internet from private subnets
```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"

# Check route table has NAT route
aws ec2 describe-route-tables --filter "Name=vpc-id,Values=<vpc-id>"

# Verify ENI has private subnet route table
aws ec2 describe-network-interfaces --network-interface-ids <eni-id>
```

### Issue: EKS Load Balancers not creating
```bash
# Verify subnet tags
aws ec2 describe-subnets --subnet-ids <subnet-id>

# Should see:
# - kubernetes.io/cluster/<cluster-name> = shared
# - kubernetes.io/role/elb = 1 (public)
# - kubernetes.io/role/internal-elb = 1 (private)
```

## Requirements

- Terraform >= 1.5.0
- AWS Provider >= 5.0
- At least 2 availability zones in the region

## Compatibility

Tested and compatible with:
- Amazon EKS 1.28, 1.29, 1.30
- AWS VPC CNI
- AWS Load Balancer Controller
- Karpenter node autoscaler

---

**Module Version**: v1.0.0
**Last Updated**: 2024
**Maintained By**: Platform Team
