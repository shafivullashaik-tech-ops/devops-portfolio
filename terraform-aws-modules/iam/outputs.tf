output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = var.create_ebs_csi_driver_role ? aws_iam_role.ebs_csi_driver[0].arn : ""
}

output "ebs_csi_driver_role_name" {
  description = "Name of the EBS CSI driver IAM role"
  value       = var.create_ebs_csi_driver_role ? aws_iam_role.ebs_csi_driver[0].name : ""
}

output "argocd_role_arn" {
  description = "ARN of the ArgoCD IAM role"
  value       = var.create_argocd_role ? aws_iam_role.argocd[0].arn : ""
}

output "jenkins_irsa_role_arn" {
  description = "ARN of the Jenkins IRSA IAM role"
  value       = var.create_jenkins_role ? aws_iam_role.jenkins_irsa[0].arn : ""
}

output "llm_gateway_irsa_role_arn" {
  description = "ARN of the LLM Gateway IRSA IAM role"
  value       = var.create_llm_gateway_role ? aws_iam_role.llm_gateway_irsa[0].arn : ""
}

output "karpenter_irsa_role_arn" {
  description = "ARN of the Karpenter IRSA IAM role"
  value       = var.create_karpenter_role ? aws_iam_role.karpenter_irsa[0].arn : ""
}

output "velero_irsa_role_arn" {
  description = "ARN of the Velero IRSA IAM role"
  value       = var.create_velero_role ? aws_iam_role.velero_irsa[0].arn : ""
}
