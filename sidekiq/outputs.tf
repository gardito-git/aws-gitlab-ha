output "security_group_id" {
  value = aws_security_group.this.id
}

output "private_ips" {
  value = { for name, i in aws_instance.this : name => i.private_ip }
}
