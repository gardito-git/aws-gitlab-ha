# Instance role: Session Manager, read the Grafana password, and
# DescribeInstances for Prometheus EC2 service discovery.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring_role" {
  name               = "gitlab-monitoring-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "monitoring_policy_document" {
  statement {
    sid       = "ReadGrafanaPassword"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.grafana_admin.arn]
  }

  statement {
    sid       = "PrometheusEc2Discovery"
    actions   = ["ec2:DescribeInstances", "ec2:DescribeAvailabilityZones"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "monitoring_policy" {
  name   = "monitoring"
  role   = aws_iam_role.monitoring_role.id
  policy = data.aws_iam_policy_document.monitoring_policy_document.json
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "gitlab-monitoring-${local.name_suffix}"
  role = aws_iam_role.monitoring_role.name
}
