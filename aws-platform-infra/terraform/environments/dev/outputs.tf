# Platform Infrastructure Outputs - Dev Environment

################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_ips
}

################################################################################
# EKS Outputs
################################################################################

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.aws_region}"
}

################################################################################
# ECR Outputs
################################################################################

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = module.ecr.repository_name
}

################################################################################
# Jenkins Outputs (when module is enabled)
################################################################################

# output "jenkins_public_ip" {
#   description = "Jenkins server public IP"
#   value       = module.jenkins.jenkins_public_ip
# }

# output "jenkins_url" {
#   description = "Jenkins URL"
#   value       = "http://${module.jenkins.jenkins_public_ip}:8080"
# }

################################################################################
# Quick Access Commands
################################################################################

output "quick_access_commands" {
  description = "Quick access commands for the infrastructure"
  value = <<-EOT

    # Configure kubectl
    ${module.eks.kubeconfig_command}

    # Verify EKS nodes
    kubectl get nodes

    # Login to ECR
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.repository_url}

    # Tag and push image to ECR
    docker tag my-app:latest ${module.ecr.repository_url}:latest
    docker push ${module.ecr.repository_url}:latest
  EOT
}
