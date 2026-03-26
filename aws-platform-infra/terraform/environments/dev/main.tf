# =============================================================================
# Platform Infrastructure — Dev Environment
#
# Enterprise pattern: this file contains ONLY module calls.
# All resources are defined inside modules in terraform-aws-modules/.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "devops-portfolio-tfstate-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "devops-portfolio-tfstate-lock-dev"
    encrypt        = true
    profile        = "shafi"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "shafi"

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "portfolio"
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

locals {
  cluster_name = "portfolio-eks-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = "devops-portfolio"
    Repository  = "aws-platform-infra"
  }
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source = "../../../../terraform-aws-modules/vpc"

  vpc_cidr     = var.vpc_cidr
  cluster_name = local.cluster_name
  environment  = var.environment

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  single_nat_gateway       = true   # cost optimisation for dev
  enable_flow_logs         = true
  flow_logs_retention_days = 7

  tags = local.common_tags
}

################################################################################
# EKS
################################################################################

module "eks" {
  source = "../../../../terraform-aws-modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs

  cluster_log_types          = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_log_retention_days = 7

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      disk_size      = 30
      capacity_type  = "ON_DEMAND"

      labels = {
        role        = "general"
        environment = var.environment
      }
    }
  }

  # EBS CSI Driver — pass IRSA role from IAM module for PVC provisioning
  ebs_csi_driver_role_arn = module.iam.ebs_csi_driver_role_arn

  tags = local.common_tags
}

################################################################################
# ECR — demo-app
################################################################################

module "ecr" {
  source = "../../../../terraform-aws-modules/ecr"

  repository_name       = var.app_name
  image_tag_mutability  = "MUTABLE"
  scan_on_push          = true
  encryption_type       = "AES256"
  image_retention_count = 10

  allowed_pull_principals = []

  tags = local.common_tags
}

################################################################################
# ECR — llm-gateway (LLMOps RAG Gateway)
################################################################################

module "ecr_llm_gateway" {
  source = "../../../../terraform-aws-modules/ecr"

  repository_name       = "llm-gateway"
  image_tag_mutability  = "MUTABLE"
  scan_on_push          = true
  encryption_type       = "AES256"
  image_retention_count = 10

  allowed_pull_principals = []

  tags = merge(local.common_tags, {
    Service = "llmops-rag-gateway"
  })
}

################################################################################
# IAM — IRSA roles for EBS CSI, Jenkins, LLM Gateway
################################################################################

module "iam" {
  source = "../../../../terraform-aws-modules/iam"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  eks_cluster_arn   = module.eks.cluster_arn

  # EBS CSI Driver (required for PVC on EKS 1.23+)
  create_ebs_csi_driver_role = true

  # ArgoCD (disabled — ArgoCD uses default SA permissions)
  create_argocd_role = false

  # Jenkins IRSA — push images to ECR, describe EKS cluster
  create_jenkins_role = true
  jenkins_namespace   = "jenkins"
  jenkins_ecr_repository_arns = [
    module.ecr.repository_arn,
    module.ecr_llm_gateway.repository_arn,
  ]

  # LLM Gateway IRSA — read secrets from AWS Secrets Manager
  create_llm_gateway_role = true

  tags = local.common_tags
}

################################################################################
# EKS Access Entries — Permanent aws-auth management via Terraform
# NEVER manage aws-auth via GitOps/ArgoCD — it breaks node authentication
################################################################################

# Node group role — required for nodes to join cluster (auto-managed by EKS)
# EKS automatically adds node group roles, but we explicitly declare for safety
resource "aws_eks_access_entry" "node_group" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.node_group_role_arn
  type          = "EC2_LINUX"

  tags = local.common_tags
}

# Admin user — shafi-terraform (break-glass cluster admin)
resource "aws_eks_access_entry" "admin_user" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::050451393596:user/shafi-terraform"
  type          = "STANDARD"

  tags = local.common_tags
}

resource "aws_eks_access_policy_association" "admin_user" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::050451393596:user/shafi-terraform"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_user]
}
