# The PostgreSQL nodes' group (not the NLB's): the consul module lets the
# Consul agents on these nodes in with it.
output "security_group_id" {
  value = aws_security_group.postgres_sg.id
}

output "endpoint" {
  description = "Host name of the NLB; port 5432 is always the current primary"
  value       = aws_lb.postgres_nlb.dns_name
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
  value = { for i, node in aws_instance.postgres : "postgres-${i + 1}" => node.private_ip }
}
