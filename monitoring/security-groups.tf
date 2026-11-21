# Every other role allows this group on its metrics ports.

resource "aws_security_group" "this" {
  name        = "gitlab-monitoring-${local.name_suffix}"
  description = "GitLab monitoring node (Prometheus, Grafana)"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-monitoring-${local.name_suffix}"
  }
}

locals {
  ingress = {
    ssh           = { port = 22, from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
    grafana       = { port = 3000, from = var.base.vpn_security_group_id, description = "Grafana" }
    prometheus    = { port = 9090, from = var.base.vpn_security_group_id, description = "Prometheus" }
    node-exporter = { port = 9100, from = aws_security_group.this.id, description = "Own node_exporter" }
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
  description       = "All outbound (scrapes, apt, grafana.com, AWS APIs)"
}
