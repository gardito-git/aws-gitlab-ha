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

resource "aws_iam_role" "this" {
  name               = "gitlab-runner-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "ReadRunnerToken"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.runner_token_secret_arn]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "runner"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_instance_profile" "this" {
  name = "gitlab-runner-${local.name_suffix}"
  role = aws_iam_role.this.name
}
