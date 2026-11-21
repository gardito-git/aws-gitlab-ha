output "security_group_id" {
  value = aws_security_group.runner_sg.id
}

output "private_ips" {
  value = { for i, node in aws_instance.runner : "runner-${i + 1}" => node.private_ip }
}
