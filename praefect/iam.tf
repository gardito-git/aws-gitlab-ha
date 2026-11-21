# Instance role: Session Manager, read the tokens and the praefect DB password.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "praefect_role" {
  name               = "gitlab-praefect-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.praefect_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "praefect_policy_document" {
  statement {
    sid     = "ReadSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.external_token.arn,
      aws_secretsmanager_secret.internal_token.arn,
      var.praefect_db_secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "praefect_policy" {
  name   = "praefect"
  role   = aws_iam_role.praefect_role.id
  policy = data.aws_iam_policy_document.praefect_policy_document.json
}

resource "aws_iam_instance_profile" "praefect" {
  name = "gitlab-praefect-${local.name_suffix}"
  role = aws_iam_role.praefect_role.name
}
