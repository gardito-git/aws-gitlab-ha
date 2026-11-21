# DNS: a PRIVATE Route 53 zone named exactly gitlab_domain, attached to the
# VPC. It resolves only inside the VPC, including for VPN clients (the Client
# VPN hands out the VPC resolver). Named after the full host, it shadows nothing.

resource "aws_route53_zone" "gitlab_zone" {
  name    = var.gitlab_domain
  comment = "GitLab (${local.name_suffix})"

  vpc {
    vpc_id = var.base.vpc_id
  }
}

resource "aws_route53_record" "gitlab_record" {
  zone_id = aws_route53_zone.gitlab_zone.zone_id
  name    = var.gitlab_domain
  type    = "A"

  alias {
    name                   = aws_lb.rails_nlb.dns_name
    zone_id                = aws_lb.rails_nlb.zone_id
    evaluate_target_health = true
  }
}

# TLS certificate for the NLB, one of two ways.

locals {
  use_public_cert = var.route53_public_zone_id != null

  certificate_arn = (
    local.use_public_cert
    ? aws_acm_certificate_validation.public[0].certificate_arn
    : aws_acm_certificate.self_signed[0].arn
  )

  # Empty with a public certificate: nothing extra to trust.
  gitlab_ca_cert = local.use_public_cert ? "" : tls_self_signed_cert.ca[0].cert_pem
}

# Option 1: real certificate from ACM, validated in your public zone.

resource "aws_acm_certificate" "public" {
  count = local.use_public_cert ? 1 : 0

  domain_name       = var.gitlab_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in try(aws_acm_certificate.public[0].domain_validation_options, []) : dvo.domain_name => dvo
  }

  zone_id         = var.route53_public_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "public" {
  count = local.use_public_cert ? 1 : 0

  certificate_arn         = aws_acm_certificate.public[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# Option 2 (default, e.g. gitlab.example.com): private CA + imported certificate.

resource "tls_private_key" "ca" {
  count = local.use_public_cert ? 0 : 1

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  count = local.use_public_cert ? 0 : 1

  private_key_pem = tls_private_key.ca[0].private_key_pem

  subject {
    common_name  = "${local.name_suffix} GitLab CA"
    organization = var.base.project_name
  }

  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses          = ["cert_signing", "crl_signing"]
}

resource "tls_private_key" "server" {
  count = local.use_public_cert ? 0 : 1

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  count = local.use_public_cert ? 0 : 1

  private_key_pem = tls_private_key.server[0].private_key_pem
  dns_names       = [var.gitlab_domain]

  subject {
    common_name = var.gitlab_domain
  }
}

resource "tls_locally_signed_cert" "server" {
  count = local.use_public_cert ? 0 : 1

  cert_request_pem   = tls_cert_request.server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720  # re-issued by any apply in the last 30 days
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

resource "aws_acm_certificate" "self_signed" {
  count = local.use_public_cert ? 0 : 1

  private_key       = tls_private_key.server[0].private_key_pem
  certificate_body  = tls_locally_signed_cert.server[0].cert_pem
  certificate_chain = tls_self_signed_cert.ca[0].cert_pem

  tags = {
    Name = "gitlab-${local.name_suffix}"
  }

  lifecycle {
    create_before_destroy = true
  }
}
