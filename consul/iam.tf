# Instance role: Session Manager, read the gossip key, and DescribeInstances
# for cloud auto-join.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consul_role" {
  name               = "gitlab-consul-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.consul_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "consul_policy_document" {
  statement {
    sid       = "ReadGossipKey"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.gossip_key.arn]
  }

  statement {
    sid       = "CloudAutoJoin"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "consul_policy" {
  name   = "consul"
  role   = aws_iam_role.consul_role.id
  policy = data.aws_iam_policy_document.consul_policy_document.json
}

resource "aws_iam_instance_profile" "consul" {
  name = "gitlab-consul-${local.name_suffix}"
  role = aws_iam_role.consul_role.name
}
