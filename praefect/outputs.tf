# The Praefect nodes' group (not the NLB's): gitaly allows Praefect in with it.
output "security_group_id" {
  value = aws_security_group.praefect_sg.id
}

output "endpoint" {
  description = "Host name of the NLB; GitLab's Gitaly address is tcp://<this>:2305"
  value       = aws_lb.praefect_nlb.dns_name
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
  value = { for i, node in aws_instance.praefect : "praefect-${i + 1}" => node.private_ip }
}
