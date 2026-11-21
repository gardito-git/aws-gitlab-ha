output "security_group_id" {
  value = aws_security_group.redis_sg.id
}

output "sentinel_hosts" {
  description = "Sentinel addresses (port 26379) for GitLab's redis_sentinels"
  value       = aws_network_interface.redis_eni[*].private_ip
}

output "master_name" {
  value = local.master_name
}

output "password_secret_arn" {
  value = aws_secretsmanager_secret.password.arn
}

output "private_ips" {
  value = { for i, eni in aws_network_interface.redis_eni : "redis-${i + 1}" => eni.private_ip }
}
