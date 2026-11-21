# Monitoring node: Prometheus + Grafana. Installed by scripts/user-data.sh.tftpl.
#
# Prometheus finds its targets itself with EC2 service discovery (every node
# is tagged Role = consul/postgres/...), so this module doesn't depend on any
# other role module and nothing has to be re-rendered when a node changes.

locals {
  name_suffix = "${var.base.project_name}-${var.base.environment}"

  # Role tag => metrics endpoints on those nodes. node_exporter (9100) is
  # scraped on every node.
  scrape_jobs = [
    { name = "consul", role = "consul", port = 8500, path = "/v1/agent/metrics", params = "format: [prometheus]" },
    { name = "patroni", role = "postgres", port = 8008, path = "/metrics", params = "" },
    { name = "postgres", role = "postgres", port = 9187, path = "/metrics", params = "" },
    { name = "redis", role = "redis", port = 9121, path = "/metrics", params = "" },
    { name = "gitaly", role = "gitaly", port = 9236, path = "/metrics", params = "" },
    { name = "praefect", role = "praefect", port = 9652, path = "/metrics", params = "" },
    { name = "gitlab-rails", role = "rails", port = 80, path = "/-/metrics", params = "" },
    { name = "gitlab-workhorse", role = "rails", port = 9229, path = "/metrics", params = "" },
    { name = "puma", role = "rails", port = 8083, path = "/metrics", params = "" },
    { name = "gitlab-exporter", role = "rails", port = 9168, path = "/metrics", params = "" },
    { name = "sidekiq", role = "sidekiq", port = 8082, path = "/metrics", params = "" },
    { name = "gitlab-runner", role = "runner", port = 9252, path = "/metrics", params = "" },
  ]
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "monitoring_key" {
  key_name   = "gitlab-monitoring-${local.name_suffix}"
  public_key = var.base.ssh_public_key
}

resource "aws_instance" "monitoring" {
  # A single node: monitoring is not on the critical path.
  ami                    = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type          = "r8i.xlarge" # 4 vCPU 32 GiB RAM
  subnet_id              = var.private_subnet_ids[0]
  key_name               = aws_key_pair.monitoring_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.monitoring.name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 100 # Prometheus data
    encrypted   = true
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    hostname                 = "gitlab-monitoring-1"
    region                   = var.base.region
    project_name             = var.base.project_name
    environment              = var.base.environment
    retention                = "15d" # how long Prometheus keeps metrics
    scrape_jobs              = local.scrape_jobs
    grafana_admin_secret_arn = aws_secretsmanager_secret.grafana_admin.arn
  }))

  tags = {
    Name = "gitlab-monitoring-1-${local.name_suffix}"
    Role = "monitoring"
  }

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  depends_on = [aws_secretsmanager_secret_version.grafana_admin]
}
