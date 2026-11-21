resource "aws_security_group" "this" {
  name        = "gitlab-consul-${local.name_suffix}"
  description = "GitLab Consul servers"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-consul-${local.name_suffix}"
  }
}

locals {
  ingress = merge(
    {
      ssh              = { port = 22, protocol = "tcp", from = var.base.vpn_security_group_id, description = "SSH from VPN clients" }
      node-exporter    = { port = 9100, protocol = "tcp", from = var.monitoring_security_group_id, description = "node_exporter" }
      rpc-peers        = { port = 8300, protocol = "tcp", from = aws_security_group.this.id, description = "Consul server RPC" }
      gossip-tcp-peers = { port = 8301, protocol = "tcp", from = aws_security_group.this.id, description = "Consul LAN gossip" }
      gossip-udp-peers = { port = 8301, protocol = "udp", from = aws_security_group.this.id, description = "Consul LAN gossip" }
      http-monitoring  = { port = 8500, protocol = "tcp", from = var.monitoring_security_group_id, description = "Consul metrics" }
      http-vpn         = { port = 8500, protocol = "tcp", from = var.base.vpn_security_group_id, description = "Consul UI" }
    },
    { for name, sg in var.agent_security_group_ids : "rpc-${name}" => { port = 8300, protocol = "tcp", from = sg, description = "Consul RPC from ${name} agents" } },
    { for name, sg in var.agent_security_group_ids : "gossip-tcp-${name}" => { port = 8301, protocol = "tcp", from = sg, description = "Consul gossip from ${name} agents" } },
    { for name, sg in var.agent_security_group_ids : "gossip-udp-${name}" => { port = 8301, protocol = "udp", from = sg, description = "Consul gossip from ${name} agents" } },
  )
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
  description       = "All outbound (apt, AWS APIs, peers)"
}
