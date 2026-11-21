# Instance role: Session Manager and read the Redis password.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redis_role" {
  name               = "gitlab-redis-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.redis_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "redis_policy_document" {
  statement {
    sid       = "ReadPassword"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.password.arn]
  }
}

resource "aws_iam_role_policy" "redis_policy" {
  name   = "redis"
  role   = aws_iam_role.redis_role.id
  policy = data.aws_iam_policy_document.redis_policy_document.json
}

resource "aws_iam_instance_profile" "redis" {
  name = "gitlab-redis-${local.name_suffix}"
  role = aws_iam_role.redis_role.name
}
