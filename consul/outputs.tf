output "security_group_id" {
  value = aws_security_group.this.id
}

output "join_tag" {
  description = "Agents join with retry_join = provider=aws tag_key=ConsulJoin tag_value=<this>"
  value       = local.join_tag
}

output "gossip_secret_arn" {
  value = aws_secretsmanager_secret.gossip_key.arn
}

output "private_ips" {
  value = { for name, i in aws_instance.this : name => i.private_ip }
}
