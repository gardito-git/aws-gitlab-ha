# Three secrets, so each consumer only gets what it needs:
#   admin       only the PostgreSQL nodes (superuser, replication, ...)
#   gitlab-db   + Rails and Sidekiq  (user gitlab, database gitlabhq_production)
#   praefect-db + Praefect           (user praefect, database praefect_production)
# special = false: the values are written into YAML, SQL and Ruby.

resource "random_password" "admin" {
  for_each = toset(["superuser", "replication", "rewind", "patroni_api", "exporter"])

  length  = 32
  special = false
}

resource "random_password" "gitlab_db" {
  length  = 32
  special = false
}

resource "random_password" "praefect_db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "admin" {
  name                    = "gitlab/${local.name_suffix}/postgres/admin"
  description             = "PostgreSQL superuser, replication, rewind, Patroni API and exporter passwords"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id     = aws_secretsmanager_secret.admin.id
  secret_string = jsonencode({ for k, p in random_password.admin : k => p.result })
}

resource "aws_secretsmanager_secret" "gitlab_db" {
  name                    = "gitlab/${local.name_suffix}/postgres/gitlab-db"
  description             = "Password of PostgreSQL user gitlab"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_db" {
  secret_id     = aws_secretsmanager_secret.gitlab_db.id
  secret_string = random_password.gitlab_db.result
}

resource "aws_secretsmanager_secret" "praefect_db" {
  name                    = "gitlab/${local.name_suffix}/postgres/praefect-db"
  description             = "Password of PostgreSQL user praefect"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "praefect_db" {
  secret_id     = aws_secretsmanager_secret.praefect_db.id
  secret_string = random_password.praefect_db.result
}
