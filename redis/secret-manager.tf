# Redis password (requirepass/masterauth). Rails and Sidekiq read it too.

resource "random_password" "password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "password" {
  name                    = "gitlab/${local.name_suffix}/redis/password"
  description             = "Redis password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.password.id
  secret_string = random_password.password.result
}
