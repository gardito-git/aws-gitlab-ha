output "security_group_id" {
  value = aws_security_group.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "prometheus_address" {
  description = "host:port, for GitLab's built-in metrics charts"
  value       = "${aws_instance.this.private_ip}:9090"
}

output "grafana_url" {
  value = "http://${aws_instance.this.private_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.this.private_ip}:9090"
}

output "grafana_admin_secret_arn" {
  value = aws_secretsmanager_secret.grafana_admin.arn
}
