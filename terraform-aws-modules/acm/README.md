# ACM Module

Manages AWS Certificate Manager (ACM) SSL/TLS certificates with automatic DNS validation via Route 53.

## Features

- Request SSL/TLS certificates
- Automatic DNS validation with Route 53
- Support for subject alternative names (SANs)
- Automatic renewal

## Usage

```hcl
module "acm" {
  source = "../../terraform-aws-modules/acm"

  domain_name = "demo.example.com"
  subject_alternative_names = [
    "*.demo.example.com",
    "api.demo.example.com"
  ]

  zone_id     = module.route53.zone_id
  environment = "prod"

  tags = {
    Terraform = "true"
    Project   = "demo"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| domain_name | Primary domain name | string | - | yes |
| subject_alternative_names | Additional domains | list(string) | [] | no |
| validation_method | Validation method | string | "DNS" | no |
| zone_id | Route 53 zone ID | string | "" | no |
| wait_for_validation | Wait for validation | bool | true | no |

## Outputs

| Name | Description |
|------|-------------|
| certificate_arn | Certificate ARN |
| certificate_id | Certificate ID |
| certificate_status | Certificate status |

## Notes

- Certificate validation can take 5-45 minutes
- Certificate automatically renews before expiration
- Wildcard certificates (*.domain.com) are supported
