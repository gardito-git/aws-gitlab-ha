# Re-export module outputs so `terraform output` shows them after apply.

# Network / VPN

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpn_endpoint_id" {
  value = module.vpc.vpn_endpoint_id
}

# Save a profile with:
#   terraform output -json vpn_client_configs | jq -r '.admin' > admin.ovpn
output "vpn_client_configs" {
  value     = module.vpc.vpn_client_configs
  sensitive = true
}

# GitLab (all reachable only while connected to the VPN)

output "gitlab_url" {
  value = module.rails.gitlab_url
}

output "gitlab_root_password_secret_arn" {
  description = "aws secretsmanager get-secret-value --secret-id <arn> --query SecretString --output text"
  value       = module.rails.root_password_secret_arn
}

output "gitlab_secrets_json_secret_arn" {
  description = "Encryption keys every GitLab node shares. Needed to restore a backup: keep a copy."
  value       = module.rails.gitlab_secrets_json_secret_arn
}

# Save and trust it on your laptop (only with the self-signed default):
#   terraform output -raw gitlab_ca_cert > gitlab-ca.crt
output "gitlab_ca_cert" {
  value = module.rails.gitlab_ca_cert
}

output "gitlab_git_ssh_host_key" {
  description = "Add to ~/.ssh/known_hosts as: <gitlab_domain> <this value>"
  value       = module.rails.git_ssh_host_key
}

output "postgres_endpoint" {
  description = "NLB; port 5432 is always the Patroni primary"
  value       = module.postgres.endpoint
}

output "praefect_endpoint" {
  description = "NLB; port 2305"
  value       = module.praefect.endpoint
}

output "node_private_ips" {
  description = "SSH as ubuntu@<ip> over the VPN"
  value = merge(
    module.consul.private_ips,
    module.postgres.private_ips,
    module.redis.private_ips,
    module.gitaly.private_ips,
    module.praefect.private_ips,
    module.rails.private_ips,
    module.sidekiq.private_ips,
    module.runner.private_ips,
    { "monitoring-1" = module.monitoring.private_ip },
  )
}

# Monitoring

output "grafana_url" {
  description = "Log in as admin; password in grafana_admin_secret_arn"
  value       = module.monitoring.grafana_url
}

output "grafana_admin_secret_arn" {
  value = module.monitoring.grafana_admin_secret_arn
}

output "prometheus_url" {
  value = module.monitoring.prometheus_url
}

output "consul_ui_url" {
  value = "http://${module.consul.private_ips["consul-1"]}:8500"
}

# Storage

output "gitlab_object_buckets" {
  value = module.s3.gitlab_object_buckets
}

output "gitlab_backup_bucket" {
  value = module.s3.gitlab_backup_bucket
}
