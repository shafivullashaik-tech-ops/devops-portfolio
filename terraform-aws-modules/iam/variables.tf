variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

# ---------------------------------------------------------------------------
# EBS CSI Driver
# ---------------------------------------------------------------------------
variable "create_ebs_csi_driver_role" {
  description = "Create IRSA role for EBS CSI driver"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# ArgoCD
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Jenkins IRSA
# ---------------------------------------------------------------------------
variable "create_jenkins_role" {
  description = "Create IRSA role for Jenkins (ECR push + EKS describe)"
  type        = bool
  default     = false
}

variable "jenkins_namespace" {
  description = "Namespace where Jenkins is installed"
  type        = string
  default     = "jenkins"
}

variable "jenkins_ecr_repository_arns" {
  description = "List of ECR repository ARNs Jenkins is allowed to push to"
  type        = list(string)
  default     = []
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster (used in Jenkins IAM policy)"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# LLM Gateway IRSA
# ---------------------------------------------------------------------------
variable "create_llm_gateway_role" {
  description = "Create IRSA role for LLM Gateway (Secrets Manager access)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Karpenter IRSA
# ---------------------------------------------------------------------------
variable "create_karpenter_role" {
  description = "Create IRSA role for Karpenter node provisioner"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Velero IRSA
# ---------------------------------------------------------------------------
variable "create_velero_role" {
  description = "Create IRSA role for Velero backup (S3 + EBS snapshots)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Common
# ---------------------------------------------------------------------------
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
