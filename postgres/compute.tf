# PostgreSQL nodes run by Patroni, with a local Consul agent as Patroni's
# leader-election store. Installed by scripts/user-data.sh.tftpl.
#
# The first node to take the Consul lock initialises the cluster and runs
# Patroni's post_bootstrap hook, which creates the gitlab and praefect users
# and databases. The others clone it and stream from it.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "postgres_key" {
  key_name   = "gitlab-postgres-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_instance" "postgres" {
  count = 3 # postgres-1..3, one per private subnet/AZ

  ami                    = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type          = "r8i.large" # 2 vCPU 16 GiB RAM
  subnet_id              = var.private_subnet_ids[count.index]
  key_name               = aws_key_pair.postgres_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname                 = "gitlab-postgres-${count.index + 1}"
    region                   = var.base.region
    vpc_cidr                 = var.base.vpc_cidr
    postgres_version         = 17
    max_connections          = 500 # No PgBouncer: every Rails/Sidekiq/Praefect connection is a PostgreSQL connection
    consul_join_tag          = var.consul_join_tag
    consul_gossip_secret_arn = var.consul_gossip_secret_arn
    admin_secret_arn         = aws_secretsmanager_secret.admin.arn
    gitlab_db_secret_arn     = aws_secretsmanager_secret.gitlab_db.arn
    praefect_db_secret_arn   = aws_secretsmanager_secret.praefect_db.arn
  }))

  tags = {
    Name = "gitlab-postgres-${count.index + 1}-${local.name_suffix}"
    Role = "postgres"
  }

  # Never rebuild a database node because of a newer AMI or an edited script.
  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [
    aws_secretsmanager_secret_version.admin,
    aws_secretsmanager_secret_version.gitlab_db,
    aws_secretsmanager_secret_version.praefect_db,
  ]
}
