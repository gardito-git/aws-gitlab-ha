# Instance role: Session Manager, S3 object storage, read the secrets Sidekiq needs.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sidekiq_role" {
  name               = "gitlab-sidekiq-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.sidekiq_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "sidekiq_policy_document" {
  statement {
    sid     = "ReadSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.gitlab_shell_secret_arn,
      var.gitlab_secrets_json_secret_arn,
      var.gitlab_db_secret_arn,
      var.redis_password_secret_arn,
      var.praefect_external_token_secret_arn,
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

resource "aws_iam_role_policy" "sidekiq_policy" {
  name   = "sidekiq"
  role   = aws_iam_role.sidekiq_role.id
  policy = data.aws_iam_policy_document.sidekiq_policy_document.json
}

resource "aws_iam_instance_profile" "sidekiq" {
  name = "gitlab-sidekiq-${local.name_suffix}"
  role = aws_iam_role.sidekiq_role.name
}
