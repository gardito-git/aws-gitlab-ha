# Instance role: Session Manager, S3 (object storage + backups), read every
# secret GitLab needs, and write the two secrets rails-1 fills in.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rails_role" {
  name               = "gitlab-rails-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.rails_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "rails_policy_document" {
  statement {
    sid     = "ReadSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.root_password.arn,
      aws_secretsmanager_secret.gitlab_shell.arn,
      aws_secretsmanager_secret.ssh_host_key.arn,
      aws_secretsmanager_secret.gitlab_secrets_json.arn,
      aws_secretsmanager_secret.runner_token.arn,
      var.gitlab_db_secret_arn,
      var.redis_password_secret_arn,
      var.praefect_external_token_secret_arn,
    ]
  }

  statement {
    sid     = "FillInGeneratedSecrets"
    actions = ["secretsmanager:PutSecretValue"]
    resources = [
      aws_secretsmanager_secret.gitlab_secrets_json.arn,
      aws_secretsmanager_secret.runner_token.arn,
    ]
  }

  statement {
    sid       = "Buckets"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"]
    resources = var.bucket_arns
  }

  statement {
    sid = "Objects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = [for arn in var.bucket_arns : "${arn}/*"]
  }
}

resource "aws_iam_role_policy" "rails_policy" {
  name   = "rails"
  role   = aws_iam_role.rails_role.id
  policy = data.aws_iam_policy_document.rails_policy_document.json
}

resource "aws_iam_instance_profile" "rails" {
  name = "gitlab-rails-${local.name_suffix}"
  role = aws_iam_role.rails_role.name
}
