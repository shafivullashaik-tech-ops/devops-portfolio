# Route 53 Module

Manages AWS Route 53 hosted zones, DNS records, and health checks.

## Features

- Hosted zone creation or use existing zone
- A records with ALB alias
- CNAME records
- Health checks with CloudWatch alarms
- ACM certificate validation records

## Usage

```hcl
module "route53" {
  source = "../../terraform-aws-modules/route53"

  domain_name = "demo.example.com"
  environment = "prod"

  # ALB record
  create_alb_record = true
  alb_record_name   = ""  # Empty for root domain
  alb_dns_name      = module.alb.dns_name
  alb_zone_id       = module.alb.zone_id

  # Health check
  create_health_check = true
  health_check_fqdn   = "demo.example.com"
  health_check_path   = "/health"

  tags = {
    Terraform = "true"
    Project   = "demo"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| domain_name | Domain name | string | - | yes |
| environment | Environment | string | - | yes |
| create_hosted_zone | Create new hosted zone | bool | true | no |
| alb_dns_name | ALB DNS name | string | "" | no |
| alb_zone_id | ALB zone ID | string | "" | no |
| create_health_check | Create health check | bool | false | no |

## Outputs

| Name | Description |
|------|-------------|
| zone_id | Hosted zone ID |
| zone_name | Hosted zone name |
| name_servers | Name servers |
| alb_record_fqdn | ALB record FQDN |
