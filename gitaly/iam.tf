# Instance role: Session Manager and read the two tokens Gitaly needs.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gitaly_role" {
  name               = "gitlab-gitaly-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.gitaly_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "gitaly_policy_document" {
  statement {
    sid     = "ReadTokens"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.gitlab_shell_secret_arn,
      var.praefect_internal_token_secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "gitaly_policy" {
  name   = "gitaly"
  role   = aws_iam_role.gitaly_role.id
  policy = data.aws_iam_policy_document.gitaly_policy_document.json
}

resource "aws_iam_instance_profile" "gitaly" {
  name = "gitlab-gitaly-${local.name_suffix}"
  role = aws_iam_role.gitaly_role.name
}
