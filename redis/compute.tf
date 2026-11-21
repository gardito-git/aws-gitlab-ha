# Redis primary + replicas, a Sentinel on each node. Installed by
# scripts/user-data.sh.tftpl.
#
# Each node gets its network interface (and so its IP) before the instance
# exists. That way every node's script already knows redis-1's address
# (the initial primary) and clients get a fixed list of Sentinels.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"
  master_name = "gitlab-redis" # name the Sentinels monitor; GitLab asks for the primary by it
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "redis_key" {
  key_name   = "gitlab-redis-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_network_interface" "redis_eni" {
  count = 3 # one per node below

  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.redis_sg.id]

  tags = {
    Name = "gitlab-redis-${count.index + 1}-${local.name_suffix}"
  }
}

resource "aws_instance" "redis" {
  count = 3 # redis-1..3, one per private subnet/AZ

  ami                  = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type        = "r8i.large" # 2 vCPU 16 GiB RAM
  key_name             = aws_key_pair.redis_key.key_name
  iam_instance_profile = aws_iam_instance_profile.redis.name

  primary_network_interface {
    network_interface_id = aws_network_interface.redis_eni[count.index].id
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname            = "gitlab-redis-${count.index + 1}"
    region              = var.base.region
    master_name         = local.master_name
    initial_primary_ip  = aws_network_interface.redis_eni[0].private_ip
    is_initial_primary  = count.index == 0
    password_secret_arn = aws_secretsmanager_secret.password.arn
  }))

  tags = {
    Name = "gitlab-redis-${count.index + 1}-${local.name_suffix}"
    Role = "redis"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [aws_secretsmanager_secret_version.password]
}
