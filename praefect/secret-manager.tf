# Gitaly Cluster tokens:
#   external-token  Rails/Sidekiq -> Praefect  (read by rails, sidekiq)
#   internal-token  Praefect -> Gitaly         (read by gitaly)

resource "random_password" "token" {
  for_each = toset(["external", "internal"])

  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "external_token" {
  name                    = "gitlab/${local.name_suffix}/praefect/external-token"
  description             = "Token GitLab uses to talk to Praefect"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "external_token" {
  secret_id     = aws_secretsmanager_secret.external_token.id
  secret_string = random_password.token["external"].result
}

resource "aws_secretsmanager_secret" "internal_token" {
  name                    = "gitlab/${local.name_suffix}/praefect/internal-token"
  description             = "Token Praefect uses to talk to Gitaly"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "internal_token" {
  secret_id     = aws_secretsmanager_secret.internal_token.id
  secret_string = random_password.token["internal"].result
}
