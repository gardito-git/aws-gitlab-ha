output "security_group_id" {
  value = aws_security_group.this.id
}

output "storages" {
  description = "Gitaly storage name => private IP (port 8075), for Praefect's virtual storage"
  value       = { for name, eni in aws_network_interface.this : name => eni.private_ip }
}

output "private_ips" {
  value = { for name, eni in aws_network_interface.this : name => eni.private_ip }
}
