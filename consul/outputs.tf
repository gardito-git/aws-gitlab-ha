output "security_group_id" {
  value = aws_security_group.consul_sg.id
}

output "join_tag" {
  description = "Agents join with retry_join = provider=aws tag_key=ConsulJoin tag_value=<this>"
  value       = local.join_tag
}

output "gossip_secret_arn" {
  value = aws_secretsmanager_secret.gossip_key.arn
}

output "private_ips" {
  value = { for i, node in aws_instance.consul : "consul-${i + 1}" => node.private_ip }
}
