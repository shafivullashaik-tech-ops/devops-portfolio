# Platform Infrastructure Variables - Dev Environment

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "platform-team"
}

################################################################################
# VPC Variables
################################################################################

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

################################################################################
# EKS Variables
################################################################################

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS API"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

################################################################################
# Application Variables
################################################################################

variable "app_name" {
  description = "Name of the application (used for ECR repository)"
  type        = string
  default     = "demo-app"
}

################################################################################
# Jenkins Variables
################################################################################

variable "ec2_key_name" {
  description = "EC2 key pair name for Jenkins instance"
  type        = string
  default     = "portfolio-key"
}

variable "jenkins_allowed_cidrs" {
  description = "CIDR blocks allowed to access Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}
