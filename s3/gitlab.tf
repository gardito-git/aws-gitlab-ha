# GitLab object storage. GitLab recommends one PRIVATE bucket per object type;
# nothing here is public. GitLab streams every download itself
# (object_store proxy_download = true), so S3 is only ever reached by the
# Rails/Sidekiq nodes through the VPC's S3 gateway endpoint.
#
# Note: gitlab-backup does NOT include object storage data. Versioning on these
# buckets is what lets you recover a deleted artifact, LFS object or upload.

locals {
  gitlab_object_types = [
    "artifacts",
    "external-diffs",
    "lfs",
    "uploads",
    "packages",
    "dependency-proxy",
    "terraform-state",
    "ci-secure-files",
    "pages",
  ]

  # type => bucket name. "backups" receives the daily gitlab-backup archives.
  gitlab_buckets = merge(
    { for t in local.gitlab_object_types : t => "${local.name_prefix}-gitlab-${t}-${local.account_id}" },
    { backups = "${local.name_prefix}-gitlab-backups-${local.account_id}" },
  )
}

resource "aws_s3_bucket" "gitlab" {
  for_each = local.gitlab_buckets

  bucket = each.value

  # false: `terraform destroy` stops at a non-empty bucket instead of silently
  # deleting repositories' artifacts and backups. Set the variable to true for
  # throwaway demo environments.
  force_destroy = var.gitlab_buckets_force_destroy

  tags = {
    Name = each.value
  }
}

resource "aws_s3_bucket_ownership_controls" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id

  # Daily backup archives expire by age (gitlab-backup never prunes S3 itself).
  dynamic "rule" {
    for_each = each.key == "backups" ? [1] : []

    content {
      id     = "expire-backups"
      status = "Enabled"

      filter {}

      expiration {
        days = var.gitlab_backup_retention_days
      }
    }
  }

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.gitlab]
}

data "aws_iam_policy_document" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [each.value.arn, "${each.value.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id
  policy = data.aws_iam_policy_document.gitlab[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.gitlab]
}
