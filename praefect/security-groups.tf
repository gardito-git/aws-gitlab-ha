resource "aws_security_group" "this" {
  name        = "gitlab-praefect-${local.name_suffix}"
  description = "GitLab Praefect nodes"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-praefect-${local.name_suffix}"
  }
}

locals {
  ingress = {
    ssh                = { port = 22, from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
    node-exporter      = { port = 9100, from = var.monitoring_security_group_id, description = "node_exporter" }
    praefect-nlb       = { port = 2305, from = aws_security_group.nlb.id, description = "Praefect via NLB" }
    metrics-monitoring = { port = 9652, from = var.monitoring_security_group_id, description = "Praefect metrics" }
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
  description       = "All outbound (apt, Gitaly, PostgreSQL, AWS APIs)"
}
