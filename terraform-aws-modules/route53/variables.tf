variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "create_hosted_zone" {
  description = "Whether to create a new hosted zone"
  type        = bool
  default     = true
}

variable "zone_id" {
  description = "Existing hosted zone ID (if create_hosted_zone is false)"
  type        = string
  default     = ""
}

variable "zone_comment" {
  description = "Comment for the hosted zone"
  type        = string
  default     = "Managed by Terraform"
}

variable "force_destroy" {
  description = "Force destroy hosted zone even if it contains records"
  type        = bool
  default     = false
}

variable "create_alb_record" {
  description = "Whether to create an A record for ALB"
  type        = bool
  default     = true
}

variable "alb_record_name" {
  description = "Name for the ALB A record (e.g., www, api, or empty for root)"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "DNS name of the ALB"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Zone ID of the ALB"
  type        = string
  default     = ""
}

variable "evaluate_target_health" {
  description = "Whether to evaluate target health for alias record"
  type        = bool
  default     = true
}

variable "cname_records" {
  description = "Map of CNAME records to create"
  type = map(object({
    ttl    = number
    record = string
  }))
  default = {}
}

variable "create_health_check" {
  description = "Whether to create a Route 53 health check"
  type        = bool
  default     = false
}

variable "health_check_fqdn" {
  description = "FQDN for health check"
  type        = string
  default     = ""
}

variable "health_check_port" {
  description = "Port for health check"
  type        = number
  default     = 443
}

variable "health_check_protocol" {
  description = "Protocol for health check (HTTP, HTTPS, TCP)"
  type        = string
  default     = "HTTPS"
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
  default     = "/health"
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive failures before marking unhealthy"
  type        = number
  default     = 3
}

variable "health_check_request_interval" {
  description = "Interval between health checks (10 or 30 seconds)"
  type        = number
  default     = 30
}

variable "create_health_check_alarm" {
  description = "Whether to create CloudWatch alarm for health check"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "certificate_validation_records" {
  description = "Map of ACM certificate validation records"
  type = map(object({
    name   = string
    type   = string
    record = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
