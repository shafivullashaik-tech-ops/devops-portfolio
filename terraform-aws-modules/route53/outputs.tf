output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : var.zone_id
}

output "zone_name" {
  description = "Route 53 hosted zone name"
  value       = var.domain_name
}

output "name_servers" {
  description = "Name servers for the hosted zone"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : []
}

output "alb_record_fqdn" {
  description = "FQDN of the ALB A record"
  value       = var.create_alb_record ? aws_route53_record.alb[0].fqdn : ""
}

output "health_check_id" {
  description = "ID of the Route 53 health check"
  value       = var.create_health_check ? aws_route53_health_check.alb[0].id : ""
}

output "cname_records" {
  description = "Map of CNAME record FQDNs"
  value = {
    for k, v in aws_route53_record.cname : k => v.fqdn
  }
}
