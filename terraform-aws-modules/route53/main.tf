terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Hosted Zone
resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0

  name          = var.domain_name
  comment       = var.zone_comment
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name        = var.domain_name
      Environment = var.environment
    }
  )
}

# A Record for ALB (Alias)
resource "aws_route53_record" "alb" {
  count = var.create_alb_record ? 1 : 0

  zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : var.zone_id
  name    = var.alb_record_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = var.evaluate_target_health
  }
}

# CNAME Records for additional domains
resource "aws_route53_record" "cname" {
  for_each = var.cname_records

  zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : var.zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = each.value.ttl
  records = [each.value.record]
}

# Health Check for ALB
resource "aws_route53_health_check" "alb" {
  count = var.create_health_check ? 1 : 0

  fqdn              = var.health_check_fqdn
  port              = var.health_check_port
  type              = var.health_check_protocol
  resource_path     = var.health_check_path
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_request_interval

  tags = merge(
    var.tags,
    {
      Name = "${var.domain_name}-health-check"
    }
  )
}

# CloudWatch Alarm for Health Check
resource "aws_cloudwatch_metric_alarm" "health_check" {
  count = var.create_health_check && var.create_health_check_alarm ? 1 : 0

  alarm_name          = "${var.domain_name}-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors Route 53 health check status"
  alarm_actions       = var.alarm_actions

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb[0].id
  }

  tags = var.tags
}

# ACM Certificate Validation Records
resource "aws_route53_record" "cert_validation" {
  for_each = var.certificate_validation_records

  zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}
