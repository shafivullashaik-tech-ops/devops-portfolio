variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "create_ebs_csi_driver_role" {
  description = "Create IRSA role for EBS CSI driver"
  type        = bool
  default     = true
}

variable "create_argocd_role" {
  description = "Create IRSA role for ArgoCD"
  type        = bool
  default     = false
}

variable "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  type        = string
  default     = "argocd"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
