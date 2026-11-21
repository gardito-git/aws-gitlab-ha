resource "aws_security_group" "this" {
  name        = "gitlab-postgres-${local.name_suffix}"
  description = "GitLab PostgreSQL/Patroni nodes"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-postgres-${local.name_suffix}"
  }
}

locals {
  ingress = {
    ssh                 = { port = 22, protocol = "tcp", from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
    node-exporter       = { port = 9100, protocol = "tcp", from = var.monitoring_security_group_id, description = "node_exporter" }
    pg-nlb              = { port = 5432, protocol = "tcp", from = aws_security_group.nlb.id, description = "PostgreSQL via NLB" }
    pg-peers            = { port = 5432, protocol = "tcp", from = aws_security_group.this.id, description = "Replication" }
    patroni-nlb         = { port = 8008, protocol = "tcp", from = aws_security_group.nlb.id, description = "Patroni /primary health check" }
    patroni-peers       = { port = 8008, protocol = "tcp", from = aws_security_group.this.id, description = "Patroni REST API between peers" }
    patroni-monitoring  = { port = 8008, protocol = "tcp", from = var.monitoring_security_group_id, description = "Patroni metrics" }
    exporter-monitoring = { port = 9187, protocol = "tcp", from = var.monitoring_security_group_id, description = "postgres_exporter" }
    gossip-tcp-peers    = { port = 8301, protocol = "tcp", from = aws_security_group.this.id, description = "Consul LAN gossip" }
    gossip-udp-peers    = { port = 8301, protocol = "udp", from = aws_security_group.this.id, description = "Consul LAN gossip" }
    gossip-tcp-consul   = { port = 8301, protocol = "tcp", from = var.consul_security_group_id, description = "Consul LAN gossip from servers" }
    gossip-udp-consul   = { port = 8301, protocol = "udp", from = var.consul_security_group_id, description = "Consul LAN gossip from servers" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value.from
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound (apt, pip, AWS APIs, peers)"
}
