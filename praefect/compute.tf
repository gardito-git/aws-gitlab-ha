# Praefect: routes Git traffic to the Gitaly nodes and keeps 3 copies of every
# repository. Its state lives in praefect_production on the PostgreSQL cluster.
# Installed by scripts/user-data.sh.tftpl; praefect-1 runs the schema migrations.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"

  nodes = {
    for i in range(var.node_count) : "praefect-${i + 1}" => {
      subnet_id = var.base.subnet_ids[i % length(var.base.subnet_ids)]
    }
  }

  gitlab_package = var.gitlab_version == "" ? "gitlab-ce" : "gitlab-ce=${var.gitlab_version}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "gitlab-praefect-${local.name_suffix}"
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
    hostname                  = "gitlab-${each.key}"
    region                    = var.base.region
    gitlab_package            = local.gitlab_package
    run_migrations            = each.key == "praefect-1"
    gitaly_storages           = var.gitaly_storages
    postgres_endpoint         = var.postgres_endpoint
    praefect_db_secret_arn    = var.praefect_db_secret_arn
    external_token_secret_arn = aws_secretsmanager_secret.external_token.arn
    internal_token_secret_arn = aws_secretsmanager_secret.internal_token.arn
  }))

  tags = {
    Name = "gitlab-${each.key}-${local.name_suffix}"
    Role = "praefect"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [
    aws_secretsmanager_secret_version.external_token,
    aws_secretsmanager_secret_version.internal_token,
  ]
}
