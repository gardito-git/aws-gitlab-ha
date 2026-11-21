# Gitaly storage nodes (GitLab CE package, Gitaly only). Only Praefect talks to
# them; Praefect keeps a copy of every repository on each node.
# Installed by scripts/user-data.sh.tftpl.
#
# Network interfaces are created first so their IPs are known up front: the
# praefect module needs the Gitaly addresses in its configuration.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"

  nodes = {
    for i in range(var.node_count) : "gitaly-${i + 1}" => {
      subnet_id = var.base.subnet_ids[i % length(var.base.subnet_ids)]
    }
  }

  gitlab_package = var.gitlab_version == "" ? "gitlab-ce" : "gitlab-ce=${var.gitlab_version}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "gitlab-gitaly-${local.name_suffix}"
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
    hostname                  = "gitlab-${each.key}"
    storage_name              = each.key
    region                    = var.base.region
    gitlab_package            = local.gitlab_package
    gitlab_url                = var.gitlab_url
    gitlab_ca_cert            = var.gitlab_ca_cert
    gitlab_shell_secret_arn   = var.gitlab_shell_secret_arn
    internal_token_secret_arn = var.praefect_internal_token_secret_arn
  }))

  tags = {
    Name = "gitlab-${each.key}-${local.name_suffix}"
    Role = "gitaly"
  }

  # Never rebuild a storage node because of a newer AMI or an edited script.
  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}
