output "security_group_id" {
  value = aws_security_group.this.id
}

output "endpoint" {
  description = "Host name of the NLB; GitLab's Gitaly address is tcp://<this>:2305"
  value       = aws_lb.this.dns_name
}

output "external_token_secret_arn" {
  description = "For Rails and Sidekiq"
  value       = aws_secretsmanager_secret.external_token.arn
}

output "internal_token_secret_arn" {
  description = "For Gitaly"
  value       = aws_secretsmanager_secret.internal_token.arn
}

output "private_ips" {
  value = { for name, i in aws_instance.this : name => i.private_ip }
}
