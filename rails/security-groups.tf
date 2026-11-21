resource "aws_security_group" "this" {
  name        = "gitlab-rails-${local.name_suffix}"
  description = "GitLab Rails nodes"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-rails-${local.name_suffix}"
  }
}

locals {
  ingress = {
    ssh                     = { port = 22, from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
    git-ssh-nlb             = { port = 22, from = aws_security_group.nlb.id, description = "Git over SSH via NLB" }
    http-nlb                = { port = 80, from = aws_security_group.nlb.id, description = "GitLab HTTP (TLS ends on the NLB)" }
    http-monitoring         = { port = 80, from = var.monitoring_security_group_id, description = "GitLab /-/metrics" }
    node-exporter           = { port = 9100, from = var.monitoring_security_group_id, description = "node_exporter" }
    workhorse-metrics       = { port = 9229, from = var.monitoring_security_group_id, description = "Workhorse metrics" }
    puma-metrics            = { port = 8083, from = var.monitoring_security_group_id, description = "Puma metrics" }
    gitlab-exporter-metrics = { port = 9168, from = var.monitoring_security_group_id, description = "gitlab-exporter metrics" }
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
