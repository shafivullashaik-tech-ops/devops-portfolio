# Platform Infrastructure - Dev Environment
# This file ONLY consumes modules - NO direct resources!
# This demonstrates enterprise best practices for Terraform structure

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

# Local variables
locals {
  cluster_name = "portfolio-eks-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = "devops-portfolio"
    Repository  = "aws-platform-infra"
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../../../../terraform-aws-modules/vpc"

  vpc_cidr     = var.vpc_cidr
  cluster_name = local.cluster_name
  environment  = var.environment

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # Cost optimization: Single NAT Gateway for dev
  single_nat_gateway = true

  # Enable VPC Flow Logs for security monitoring
  enable_flow_logs          = true
  flow_logs_retention_days  = 7

  tags = local.common_tags
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "../../../../terraform-aws-modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # API endpoint access
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs

  # Enable all control plane logs for monitoring
  cluster_log_types        = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_log_retention_days = 7

  # Node groups configuration
  node_groups = {
    general = {
      instance_types  = ["t3.medium"]
      desired_size    = 2
      min_size        = 1
      max_size        = 3
      disk_size       = 30
      capacity_type   = "ON_DEMAND"

      labels = {
        role        = "general"
        environment = var.environment
      }
    }
  }

  tags = local.common_tags
}

################################################################################
# ECR Module
################################################################################

module "ecr" {
  source = "../../../../terraform-aws-modules/ecr"

  repository_name        = var.app_name
  image_tag_mutability   = "MUTABLE"
  scan_on_push           = true
  encryption_type        = "AES256"
  image_retention_count  = 10

  # Allow Jenkins to push images
  # Note: Add Jenkins IAM role ARN after Jenkins is created
  allowed_pull_principals = []

  tags = local.common_tags
}

################################################################################
# Jenkins IRSA - IAM Role for Jenkins to access ECR & EKS
################################################################################

resource "aws_iam_role" "jenkins_irsa" {
  name = "${local.cluster_name}-jenkins-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:jenkins:jenkins"
          "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "jenkins_ecr_policy" {
  name = "${local.cluster_name}-jenkins-ecr-policy"
  role = aws_iam_role.jenkins_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = module.ecr.repository_arn
      },
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}

output "jenkins_irsa_role_arn" {
  description = "IAM Role ARN for Jenkins IRSA"
  value       = aws_iam_role.jenkins_irsa.arn
}

################################################################################
# Jenkins Module (Placeholder)
# Uncomment when Jenkins module is ready
################################################################################

# module "jenkins" {
#   source = "../../../../terraform-aws-modules/jenkins"
#
#   vpc_id            = module.vpc.vpc_id
#   subnet_id         = module.vpc.public_subnet_ids[0]
#   instance_type     = "t3.small"
#   key_name          = var.ec2_key_name
#
#   # Grant Jenkins permissions to ECR and EKS
#   ecr_repository_arns = [module.ecr.repository_arn]
#   eks_cluster_name    = module.eks.cluster_id
#
#   allowed_cidr_blocks = var.jenkins_allowed_cidrs
#
#   tags = local.common_tags
# }

################################################################################
# IAM Module for IRSA (Placeholder)
# Uncomment when IAM module is ready
################################################################################

# module "iam" {
#   source = "../../../../terraform-aws-modules/iam"
#
#   cluster_name       = local.cluster_name
#   oidc_provider_arn  = module.eks.oidc_provider_arn
#
#   # Create IRSA role for ArgoCD
#   create_argocd_role = true
#   argocd_namespace   = "argocd"
#
#   # Create IRSA role for application
#   create_app_role = true
#   app_namespace   = "default"
#   app_s3_buckets  = []
#
#   tags = local.common_tags
# }
