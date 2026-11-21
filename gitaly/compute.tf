# Gitaly storage nodes (GitLab CE package, Gitaly only). Only Praefect talks to
# them; Praefect keeps a copy of every repository on each node.
# Installed by scripts/user-data.sh.tftpl.
#
# Network interfaces are created first so their IPs are known up front: the
# praefect module needs the Gitaly addresses in its configuration.

locals {
  name_suffix    = "${var.base.project_name}-${var.base.environment}"
  gitlab_package = var.gitlab_version == "" ? "gitlab-ce" : "gitlab-ce=${var.gitlab_version}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "gitaly_key" {
  key_name   = "gitlab-gitaly-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_network_interface" "gitaly_eni" {
  count = 3 # one per node below

  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.gitaly_sg.id]

  tags = {
    Name = "gitlab-gitaly-${count.index + 1}-${local.name_suffix}"
  }
}

resource "aws_instance" "gitaly" {
  count = 3 # gitaly-1..3, one per private subnet/AZ; also the storage names

  ami                  = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type        = "m8i.large" # 2 vCPU 8 GiB RAM
  key_name             = aws_key_pair.gitaly_key.key_name
  iam_instance_profile = aws_iam_instance_profile.gitaly.name

  primary_network_interface {
    network_interface_id = aws_network_interface.gitaly_eni[count.index].id
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 200 # holds the Git repositories
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname                  = "gitlab-gitaly-${count.index + 1}"
    storage_name              = "gitaly-${count.index + 1}"
    region                    = var.base.region
    gitlab_package            = local.gitlab_package
    gitlab_url                = var.gitlab_url
    gitlab_ca_cert            = var.gitlab_ca_cert
    gitlab_shell_secret_arn   = var.gitlab_shell_secret_arn
    internal_token_secret_arn = var.praefect_internal_token_secret_arn
  }))

  tags = {
    Name = "gitlab-gitaly-${count.index + 1}-${local.name_suffix}"
    Role = "gitaly"
  }

  # Never rebuild a storage node because of a newer AMI or an edited script.
  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}
