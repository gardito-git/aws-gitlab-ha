output "security_group_id" {
  value = aws_security_group.gitaly_sg.id
}

output "storages" {
  description = "Gitaly storage name => private IP (port 8075), for Praefect's virtual storage"
  value       = { for i, eni in aws_network_interface.gitaly_eni : "gitaly-${i + 1}" => eni.private_ip }
}

output "private_ips" {
  value = { for i, eni in aws_network_interface.gitaly_eni : "gitaly-${i + 1}" => eni.private_ip }
}
