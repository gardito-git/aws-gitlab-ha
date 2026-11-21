resource "aws_security_group" "this" {
  name        = "gitlab-sidekiq-${local.name_suffix}"
  description = "GitLab Sidekiq nodes"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-sidekiq-${local.name_suffix}"
  }
}

locals {
  ingress = {
    ssh                = { port = 22, from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
    node-exporter      = { port = 9100, from = var.monitoring_security_group_id, description = "node_exporter" }
    metrics-monitoring = { port = 8082, from = var.monitoring_security_group_id, description = "Sidekiq metrics" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value.from
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound (apt, PostgreSQL, Redis, Praefect, S3, AWS APIs)"
}
