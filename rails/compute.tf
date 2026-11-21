# GitLab Rails nodes: web UI, API, Git over HTTPS and SSH (GitLab CE package).
# Installed by scripts/user-data.sh.tftpl.
#
# rails-1 is special: it runs the database migrations, generates
# gitlab-secrets.json (the encryption keys every Rails/Sidekiq node must share)
# and stores it in Secrets Manager, creates the runner token, and runs the daily
# backup. rails-2/3 and the Sidekiq nodes wait for that secret, then join.

locals {
  name_suffix    = "${var.base.project_name}-${var.base.environment}"
  gitlab_url     = "https://${var.gitlab_domain}"
  gitlab_package = var.gitlab_version == "" ? "gitlab-ce" : "gitlab-ce=${var.gitlab_version}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "rails_key" {
  key_name   = "gitlab-rails-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_instance" "rails" {
  count = 3 # rails-1..3, one per private subnet/AZ

  ami                    = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type          = "c8i.xlarge" # 4 vCPU 8 GiB RAM
  subnet_id              = var.private_subnet_ids[count.index]
  key_name               = aws_key_pair.rails_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.rails.name
  vpc_security_group_ids = [aws_security_group.rails_sg.id]

  # IMDSv2, hop limit 1: GitLab gets the instance role for S3.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 100 # also holds the local backup archive before upload
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname       = "gitlab-rails-${count.index + 1}"
    is_primary     = count.index == 0 # rails-1
    region         = var.base.region
    vpc_cidr       = var.base.vpc_cidr
    gitlab_package = local.gitlab_package
    gitlab_url     = local.gitlab_url
    gitlab_ca_cert = local.gitlab_ca_cert

    postgres_endpoint                  = var.postgres_endpoint
    gitlab_db_secret_arn               = var.gitlab_db_secret_arn
    redis_sentinel_hosts               = var.redis_sentinel_hosts
    redis_master_name                  = var.redis_master_name
    redis_password_secret_arn          = var.redis_password_secret_arn
    praefect_endpoint                  = var.praefect_endpoint
    praefect_external_token_secret_arn = var.praefect_external_token_secret_arn
    object_buckets                     = var.object_buckets
    backup_bucket                      = var.backup_bucket
    backup_cron                        = "0 0 * * *" # daily at 00:00 UTC (nodes run in UTC)
    prometheus_address                 = var.prometheus_address

    root_password_secret_arn  = aws_secretsmanager_secret.root_password.arn
    gitlab_shell_secret_arn   = aws_secretsmanager_secret.gitlab_shell.arn
    ssh_host_key_secret_arn   = aws_secretsmanager_secret.ssh_host_key.arn
    gitlab_secrets_secret_arn = aws_secretsmanager_secret.gitlab_secrets_json.arn
    runner_token_secret_arn   = aws_secretsmanager_secret.runner_token.arn
  }))

  tags = {
    Name = "gitlab-rails-${count.index + 1}-${local.name_suffix}"
    Role = "rails"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [
    aws_secretsmanager_secret_version.root_password,
    aws_secretsmanager_secret_version.gitlab_shell,
    aws_secretsmanager_secret_version.ssh_host_key,
  ]
}
