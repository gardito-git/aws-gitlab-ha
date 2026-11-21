output "security_group_id" {
  value = aws_security_group.this.id
}

output "endpoint" {
  description = "Host name of the NLB; port 5432 is always the current primary"
  value       = aws_lb.this.dns_name
}

output "gitlab_db_secret_arn" {
  description = "Password of user gitlab (database gitlabhq_production)"
  value       = aws_secretsmanager_secret.gitlab_db.arn
}

output "praefect_db_secret_arn" {
  description = "Password of user praefect (database praefect_production)"
  value       = aws_secretsmanager_secret.praefect_db.arn
}

output "admin_secret_arn" {
  value = aws_secretsmanager_secret.admin.arn
}

output "private_ips" {
  value = { for name, i in aws_instance.this : name => i.private_ip }
}
