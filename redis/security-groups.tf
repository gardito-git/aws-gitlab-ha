resource "aws_security_group" "redis_sg" {
  name        = "gitlab-redis-${local.name_suffix}"
  description = "GitLab Redis + Sentinel nodes"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-redis-${local.name_suffix}"
  }
}

locals {
  ingress = merge(
    {
      ssh                 = { port = 22, from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
      node-exporter       = { port = 9100, from = var.monitoring_security_group_id, description = "node_exporter" }
      exporter-monitoring = { port = 9121, from = var.monitoring_security_group_id, description = "redis_exporter" }
      redis-peers         = { port = 6379, from = aws_security_group.redis_sg.id, description = "Redis replication" }
      sentinel-peers      = { port = 26379, from = aws_security_group.redis_sg.id, description = "Sentinel to Sentinel" }
    },
    { for name, sg in var.client_security_group_ids : "redis-${name}" => { port = 6379, from = sg, description = "Redis from ${name}" } },
    { for name, sg in var.client_security_group_ids : "sentinel-${name}" => { port = 26379, from = sg, description = "Sentinel from ${name}" } },
  )
}

resource "aws_vpc_security_group_ingress_rule" "redis_sg_ingress" {
  for_each = local.ingress

  security_group_id            = aws_security_group.redis_sg.id
  referenced_security_group_id = each.value.from
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "redis_sg_egress_all" {
  security_group_id = aws_security_group.redis_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound (apt, AWS APIs, peers)"
}
