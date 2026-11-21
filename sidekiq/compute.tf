# Sidekiq nodes: GitLab background jobs (GitLab CE package, Sidekiq only).
# Installed by scripts/user-data.sh.tftpl, which waits for rails-1 to publish
# gitlab-secrets.json before configuring.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"

  nodes = {
    for i in range(var.node_count) : "sidekiq-${i + 1}" => {
      subnet_id = var.base.subnet_ids[i % length(var.base.subnet_ids)]
    }
  }

  gitlab_package = var.gitlab_version == "" ? "gitlab-ce" : "gitlab-ce=${var.gitlab_version}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "gitlab-sidekiq-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_instance" "this" {
  for_each = local.nodes

  ami                    = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type          = var.instance_type
  subnet_id              = each.value.subnet_id
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname        = "gitlab-${each.key}"
    region          = var.base.region
    gitlab_package  = local.gitlab_package
    gitlab_url      = var.gitlab_url
    gitlab_ca_cert  = var.gitlab_ca_cert
    max_concurrency = var.max_concurrency

    gitlab_shell_secret_arn            = var.gitlab_shell_secret_arn
    gitlab_secrets_secret_arn          = var.gitlab_secrets_json_secret_arn
    postgres_endpoint                  = var.postgres_endpoint
    gitlab_db_secret_arn               = var.gitlab_db_secret_arn
    redis_sentinel_hosts               = var.redis_sentinel_hosts
    redis_master_name                  = var.redis_master_name
    redis_password_secret_arn          = var.redis_password_secret_arn
    praefect_endpoint                  = var.praefect_endpoint
    praefect_external_token_secret_arn = var.praefect_external_token_secret_arn
    object_buckets                     = var.object_buckets
  }))

  tags = {
    Name = "gitlab-${each.key}-${local.name_suffix}"
    Role = "sidekiq"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}
