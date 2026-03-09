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
