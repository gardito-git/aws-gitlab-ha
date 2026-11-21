# Instance role: Session Manager and read the runner token. Nothing else:
# CI jobs should not inherit AWS permissions from the machine.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner_role" {
  name               = "gitlab-runner-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "runner_policy_document" {
  statement {
    sid       = "ReadRunnerToken"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.runner_token_secret_arn]
  }
}

resource "aws_iam_role_policy" "runner_policy" {
  name   = "runner"
  role   = aws_iam_role.runner_role.id
  policy = data.aws_iam_policy_document.runner_policy_document.json
}

resource "aws_iam_instance_profile" "runner" {
  name = "gitlab-runner-${local.name_suffix}"
  role = aws_iam_role.runner_role.name
}
