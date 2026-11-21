# Consul servers: the leader-election store Patroni uses to decide which
# PostgreSQL node is the primary. Installed by scripts/user-data.sh.tftpl.
#
# Servers and agents find each other with Consul's AWS cloud auto-join: every
# server carries the tag ConsulJoin = <local.join_tag>, so nobody needs to
# know the others' IPs in advance.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"
  join_tag    = "gitlab-${local.name_suffix}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "consul_key" {
  key_name   = "gitlab-consul-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_instance" "consul" {
  count = 3 # consul-1..3, one per private subnet/AZ; keep it odd (3 or 5) for a quorum

  ami                    = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type          = "c8i.large" # 2 vCPU 4 GiB RAM
  subnet_id              = var.private_subnet_ids[count.index]
  key_name               = aws_key_pair.consul_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.consul.name
  vpc_security_group_ids = [aws_security_group.consul_sg.id]

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
    hostname          = "gitlab-consul-${count.index + 1}"
    region            = var.base.region
    node_count        = 3 # bootstrap_expect: same as count above
    join_tag          = local.join_tag
    gossip_secret_arn = aws_secretsmanager_secret.gossip_key.arn
  }))

  tags = {
    Name       = "gitlab-consul-${count.index + 1}-${local.name_suffix}"
    Role       = "consul"
    ConsulJoin = local.join_tag
  }

  # A newer AMI or an edited script must not rebuild a running node.
  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [aws_secretsmanager_secret_version.gossip_key]
}
