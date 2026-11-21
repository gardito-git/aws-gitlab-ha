# Values this module hands back to its caller, read as module.s3.<name>.

output "private_bucket_name" {
  value = aws_s3_bucket.private.id
}

output "private_bucket_arn" {
  description = "For IAM policies that grant other services access to a prefix"
  value       = aws_s3_bucket.private.arn
}

output "gitlab_object_buckets" {
  description = "GitLab object type (artifacts, lfs, ...) => bucket name"
  value       = { for k, b in aws_s3_bucket.gitlab : k => b.id if k != "backups" }
}

output "gitlab_backup_bucket" {
  description = "Bucket receiving the daily gitlab-backup archives"
  value       = aws_s3_bucket.gitlab["backups"].id
}

output "gitlab_bucket_arns" {
  description = "Every GitLab bucket, for the Rails/Sidekiq IAM policy"
  value       = [for b in aws_s3_bucket.gitlab : b.arn]
}
