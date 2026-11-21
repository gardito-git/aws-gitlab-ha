# Consul servers: the leader-election store Patroni uses to decide which
# PostgreSQL node is the primary. Installed by scripts/user-data.sh.tftpl.
#
# Servers and agents find each other with Consul's AWS cloud auto-join: every
# server carries the tag ConsulJoin = <local.join_tag>, so nobody needs to
# know the others' IPs in advance.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"
  join_tag    = "gitlab-${local.name_suffix}"

  # "consul-1" => AZ a, "consul-2" => b, "consul-3" => c, ...
  nodes = {
    for i in range(var.node_count) : "consul-${i + 1}" => {
      subnet_id = var.base.subnet_ids[i % length(var.base.subnet_ids)]
    }
  }
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "gitlab-consul-${local.name_suffix}"
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
    hostname          = "gitlab-${each.key}"
    region            = var.base.region
    node_count        = var.node_count
    join_tag          = local.join_tag
    gossip_secret_arn = aws_secretsmanager_secret.gossip_key.arn
  }))

  tags = {
    Name       = "gitlab-${each.key}-${local.name_suffix}"
    Role       = "consul"
    ConsulJoin = local.join_tag
  }

  # A newer AMI or an edited script must not rebuild a running node.
  # To re-provision one on purpose: terraform apply -replace='module.consul.aws_instance.this["consul-1"]'
  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [aws_secretsmanager_secret_version.gossip_key]
}
