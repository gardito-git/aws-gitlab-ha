# Secrets owned by the Rails role:
#   root-password        GitLab "root" user, first login
#   gitlab-shell-token   shared with Sidekiq and Gitaly (Git hooks -> internal API)
#   ssh-host-key         one SSH host key for all Rails nodes, so Git over SSH
#                        through the NLB never shows "host key changed"
#   gitlab-secrets-json  NO value from Terraform: rails-1 uploads its
#                        /etc/gitlab/gitlab-secrets.json after the first
#                        reconfigure; the other Rails and Sidekiq nodes wait for it
#   runner-token         NO value from Terraform: rails-1 creates the instance
#                        runner and stores its token; the runners wait for it

resource "random_password" "root" {
  length  = 32
  special = false
}

resource "random_password" "gitlab_shell" {
  length  = 64
  special = false
}

resource "tls_private_key" "ssh_host" {
  algorithm = "ED25519"
}

resource "aws_secretsmanager_secret" "root_password" {
  name                    = "gitlab/${local.name_suffix}/rails/root-password"
  description             = "GitLab root user password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "root_password" {
  secret_id     = aws_secretsmanager_secret.root_password.id
  secret_string = random_password.root.result
}

resource "aws_secretsmanager_secret" "gitlab_shell" {
  name                    = "gitlab/${local.name_suffix}/rails/gitlab-shell-token"
  description             = "gitlab-shell secret token (Rails, Sidekiq, Gitaly)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_shell" {
  secret_id     = aws_secretsmanager_secret.gitlab_shell.id
  secret_string = random_password.gitlab_shell.result
}

resource "aws_secretsmanager_secret" "ssh_host_key" {
  name                    = "gitlab/${local.name_suffix}/rails/ssh-host-key"
  description             = "Shared SSH host key of the Rails nodes"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ssh_host_key" {
  secret_id = aws_secretsmanager_secret.ssh_host_key.id
  secret_string = jsonencode({
    private = tls_private_key.ssh_host.private_key_openssh
    public  = tls_private_key.ssh_host.public_key_openssh
  })
}

resource "aws_secretsmanager_secret" "gitlab_secrets_json" {
  name                    = "gitlab/${local.name_suffix}/rails/gitlab-secrets-json"
  description             = "/etc/gitlab/gitlab-secrets.json, uploaded by rails-1. Needed to restore backups: keep a copy."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "runner_token" {
  name                    = "gitlab/${local.name_suffix}/rails/runner-token"
  description             = "Runner authentication token (glrt-...), created by rails-1"
  recovery_window_in_days = 0
}
