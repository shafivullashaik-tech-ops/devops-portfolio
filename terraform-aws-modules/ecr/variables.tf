# ECR Module Variables

variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-_/]+$", var.repository_name))
    error_message = "Repository name must contain only lowercase letters, numbers, hyphens, underscores, and slashes."
  }
}

variable "image_tag_mutability" {
  description = "Tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type (AES256 or KMS)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "Encryption type must be either AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption (required if encryption_type is KMS)"
  type        = string
  default     = null
}

variable "image_retention_count" {
  description = "Number of images to retain in the repository"
  type        = number
  default     = 10

  validation {
    condition     = var.image_retention_count > 0
    error_message = "Image retention count must be greater than 0."
  }
}

variable "allowed_pull_principals" {
  description = "List of AWS principal ARNs allowed to pull images"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for the repository"
  type        = map(string)
  default     = {}
}
