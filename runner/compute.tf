# GitLab Runner machines with the Docker executor: every CI job runs in a
# fresh container. Installed by scripts/user-data.sh.tftpl, which waits for
# rails-1 to publish the runner token, then registers.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"

  nodes = {
    for i in range(var.node_count) : "runner-${i + 1}" => {
      subnet_id = var.base.subnet_ids[i % length(var.base.subnet_ids)]
    }
  }
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "gitlab-runner-${local.name_suffix}"
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

  # Hop limit 1: CI job containers cannot reach the metadata service, so they
  # cannot borrow this machine's AWS role.
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
    hostname                = "gitlab-${each.key}"
    region                  = var.base.region
    gitlab_url              = var.gitlab_url
    gitlab_host             = replace(var.gitlab_url, "https://", "")
    gitlab_ca_cert          = var.gitlab_ca_cert
    runner_token_secret_arn = var.runner_token_secret_arn
    concurrent              = var.concurrent
    default_image           = var.default_image
  }))

  tags = {
    Name = "gitlab-${each.key}-${local.name_suffix}"
    Role = "runner"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}
