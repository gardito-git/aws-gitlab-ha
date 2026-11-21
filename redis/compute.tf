# Redis primary + replicas, a Sentinel on each node. Installed by
# scripts/user-data.sh.tftpl.
#
# Each node gets its network interface (and so its IP) before the instance
# exists. That way every node's script already knows redis-1's address
# (the initial primary) and clients get a fixed list of Sentinels.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"

  nodes = {
    for i in range(var.node_count) : "redis-${i + 1}" => {
      subnet_id = var.base.subnet_ids[i % length(var.base.subnet_ids)]
    }
  }
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "gitlab-redis-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_network_interface" "this" {
  for_each = local.nodes

  subnet_id       = each.value.subnet_id
  security_groups = [aws_security_group.this.id]

  tags = {
    Name = "gitlab-${each.key}-${local.name_suffix}"
  }
}

resource "aws_instance" "this" {
  for_each = local.nodes

  ami                  = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type        = var.instance_type
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.this.name

  primary_network_interface {
    network_interface_id = aws_network_interface.this[each.key].id
  }

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
    hostname            = "gitlab-${each.key}"
    region              = var.base.region
    master_name         = var.master_name
    initial_primary_ip  = aws_network_interface.this["redis-1"].private_ip
    is_initial_primary  = each.key == "redis-1"
    password_secret_arn = aws_secretsmanager_secret.password.arn
  }))

  tags = {
    Name = "gitlab-${each.key}-${local.name_suffix}"
    Role = "redis"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [aws_secretsmanager_secret_version.password]
}
