# PostgreSQL nodes run by Patroni, with a local Consul agent as Patroni's
# leader-election store. Installed by scripts/user-data.sh.tftpl.
#
# The first node to take the Consul lock initialises the cluster and runs
# Patroni's post_bootstrap hook, which creates the gitlab and praefect users
# and databases. The others clone it and stream from it.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"

  nodes = {
    for i in range(var.node_count) : "postgres-${i + 1}" => {
      subnet_id = var.base.subnet_ids[i % length(var.base.subnet_ids)]
    }
  }
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "gitlab-postgres-${local.name_suffix}"
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
    hostname                 = "gitlab-${each.key}"
    region                   = var.base.region
    vpc_cidr                 = var.base.vpc_cidr
    postgres_version         = var.postgres_version
    max_connections          = var.max_connections
    consul_join_tag          = var.consul_join_tag
    consul_gossip_secret_arn = var.consul_gossip_secret_arn
    admin_secret_arn         = aws_secretsmanager_secret.admin.arn
    gitlab_db_secret_arn     = aws_secretsmanager_secret.gitlab_db.arn
    praefect_db_secret_arn   = aws_secretsmanager_secret.praefect_db.arn
  }))

  tags = {
    Name = "gitlab-${each.key}-${local.name_suffix}"
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
