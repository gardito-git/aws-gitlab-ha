output "security_group_id" {
  value = aws_security_group.this.id
}

output "sentinel_hosts" {
  description = "Sentinel addresses (port 26379) for GitLab's redis_sentinels"
  value       = [for name in sort(keys(local.nodes)) : aws_network_interface.this[name].private_ip]
}

output "master_name" {
  value = var.master_name
}

output "password_secret_arn" {
  value = aws_secretsmanager_secret.password.arn
}

output "private_ips" {
  value = { for name, eni in aws_network_interface.this : name => eni.private_ip }
}
