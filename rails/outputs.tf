output "security_group_id" {
  value = aws_security_group.this.id
}

output "gitlab_url" {
  value = local.gitlab_url
}

output "frontend_nlb_dns_name" {
  value = aws_lb.this.dns_name
}

output "gitlab_ca_cert" {
  description = "CA to trust (empty when a public ACM certificate is used)"
  value       = local.gitlab_ca_cert
}

output "git_ssh_host_key" {
  description = "Public SSH host key of gitlab_domain, for ~/.ssh/known_hosts"
  value       = trimspace(tls_private_key.ssh_host.public_key_openssh)
}

output "root_password_secret_arn" {
  value = aws_secretsmanager_secret.root_password.arn
}

output "gitlab_shell_secret_arn" {
  description = "For Sidekiq and Gitaly"
  value       = aws_secretsmanager_secret.gitlab_shell.arn
}

output "gitlab_secrets_json_secret_arn" {
  description = "For Sidekiq; also what you need to restore a backup"
  value       = aws_secretsmanager_secret.gitlab_secrets_json.arn
}

output "runner_token_secret_arn" {
  description = "For the runners"
  value       = aws_secretsmanager_secret.runner_token.arn
}

output "private_ips" {
  value = { for name, i in aws_instance.this : name => i.private_ip }
}
