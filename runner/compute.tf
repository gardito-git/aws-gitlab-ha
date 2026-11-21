# GitLab Runner machines with the Docker executor: every CI job runs in a
# fresh container. Installed by scripts/user-data.sh.tftpl, which waits for
# rails-1 to publish the runner token, then registers.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "runner_key" {
  key_name   = "gitlab-runner-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_instance" "runner" {
  count = 6 # runner-1..6, two per private subnet/AZ (1->a, 2->b, 3->c, 4->a ...)

  ami                    = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type          = "c8i.xlarge" # 4 vCPU 8 GiB RAM
  subnet_id              = var.private_subnet_ids[count.index % 3]
  key_name               = aws_key_pair.runner_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.runner.name
  vpc_security_group_ids = [aws_security_group.runner_sg.id]

  # Hop limit 1: CI job containers cannot reach the metadata service, so they
  # cannot borrow this machine's AWS role.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 100 # Docker images and build caches
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname                = "gitlab-runner-${count.index + 1}"
    region                  = var.base.region
    gitlab_url              = var.gitlab_url
    gitlab_host             = replace(var.gitlab_url, "https://", "")
    gitlab_ca_cert          = var.gitlab_ca_cert
    runner_token_secret_arn = var.runner_token_secret_arn
    concurrent              = 4               # CI jobs at once per machine (4 vCPU)
    default_image           = "alpine:latest" # for jobs that don't set an image
  }))

  tags = {
    Name = "gitlab-runner-${count.index + 1}-${local.name_suffix}"
    Role = "runner"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}
