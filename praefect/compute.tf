# Praefect: routes Git traffic to the Gitaly nodes and keeps 3 copies of every
# repository. Its state lives in praefect_production on the PostgreSQL cluster.
# Installed by scripts/user-data.sh.tftpl; praefect-1 runs the schema migrations.

locals {
  name_suffix    = "${var.base.project_name}-${var.base.environment}"
  gitlab_package = var.gitlab_version == "" ? "gitlab-ce" : "gitlab-ce=${var.gitlab_version}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "praefect_key" {
  key_name   = "gitlab-praefect-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_instance" "praefect" {
  count = 3 # praefect-1..3, one per private subnet/AZ

  ami                    = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type          = "c8i.large" # 2 vCPU 4 GiB RAM
  subnet_id              = var.private_subnet_ids[count.index]
  key_name               = aws_key_pair.praefect_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.praefect.name
  vpc_security_group_ids = [aws_security_group.praefect_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname                  = "gitlab-praefect-${count.index + 1}"
    region                    = var.base.region
    gitlab_package            = local.gitlab_package
    run_migrations            = count.index == 0 # praefect-1 only
    gitaly_storages           = var.gitaly_storages
    postgres_endpoint         = var.postgres_endpoint
    praefect_db_secret_arn    = var.praefect_db_secret_arn
    external_token_secret_arn = aws_secretsmanager_secret.external_token.arn
    internal_token_secret_arn = aws_secretsmanager_secret.internal_token.arn
  }))

  tags = {
    Name = "gitlab-praefect-${count.index + 1}-${local.name_suffix}"
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
