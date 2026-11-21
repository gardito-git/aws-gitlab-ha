# Instance role: Session Manager, read its secrets and the Consul gossip key,
# DescribeInstances for Consul cloud auto-join.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "postgres_role" {
  name               = "gitlab-postgres-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.postgres_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "postgres_policy_document" {
  statement {
    sid     = "ReadSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.admin.arn,
      aws_secretsmanager_secret.gitlab_db.arn,
      aws_secretsmanager_secret.praefect_db.arn,
      var.consul_gossip_secret_arn,
    ]
  }

  statement {
    sid       = "ConsulCloudAutoJoin"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "postgres_policy" {
  name   = "postgres"
  role   = aws_iam_role.postgres_role.id
  policy = data.aws_iam_policy_document.postgres_policy_document.json
}

resource "aws_iam_instance_profile" "postgres" {
  name = "gitlab-postgres-${local.name_suffix}"
  role = aws_iam_role.postgres_role.name
}
