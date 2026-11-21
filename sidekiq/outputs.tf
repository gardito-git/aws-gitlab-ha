output "security_group_id" {
  value = aws_security_group.sidekiq_sg.id
}

output "private_ips" {
  value = { for i, node in aws_instance.sidekiq : "sidekiq-${i + 1}" => node.private_ip }
}
