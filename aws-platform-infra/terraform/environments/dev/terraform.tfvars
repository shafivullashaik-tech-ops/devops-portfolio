# Dev Environment - Terraform Variables
# AWS Account: 911046881165
# Region: us-east-1

aws_region  = "us-east-1"
environment = "dev"
owner       = "shafi"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# EKS Configuration
kubernetes_version      = "1.28"
eks_public_access_cidrs = ["0.0.0.0/0"]

# Application
app_name = "demo-app"

# Jenkins
ec2_key_name          = "portfolio-key"
jenkins_allowed_cidrs = ["0.0.0.0/0"]
