resource "aws_security_group" "gitaly_sg" {
  name        = "gitlab-gitaly-${local.name_suffix}"
  description = "GitLab Gitaly storage nodes"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-gitaly-${local.name_suffix}"
  }
}

locals {
  ingress = {
    ssh                = { port = 22, from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
    node-exporter      = { port = 9100, from = var.monitoring_security_group_id, description = "node_exporter" }
    gitaly-praefect    = { port = 8075, from = var.praefect_security_group_id, description = "Gitaly from Praefect" }
    metrics-monitoring = { port = 9236, from = var.monitoring_security_group_id, description = "Gitaly metrics" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "gitaly_sg_ingress" {
  for_each = local.ingress

  security_group_id            = aws_security_group.gitaly_sg.id
  referenced_security_group_id = each.value.from
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "gitaly_sg_egress_all" {
  security_group_id = aws_security_group.gitaly_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound (apt, GitLab internal API, AWS APIs)"
}
