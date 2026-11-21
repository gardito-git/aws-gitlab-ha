# Inputs this module accepts. The root module passes them in via the
# module "s3" block in main.tf.

variable "project_name" {
  type        = string
  description = "Project name used in bucket and resource names"
}

variable "environment" {
  type        = string
  description = "Environment name used in bucket and resource names"
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Objects under logs/ in the private bucket are deleted after this many days"
}

variable "backup_retention_days" {
  type        = number
  default     = 30
  description = "Kubernetes etcd snapshots (backups/kubernetes/) are deleted after this many days. PostgreSQL retention is set in postgres-cluster (backup_retention_full)."
}

variable "noncurrent_version_retention_days" {
  type        = number
  default     = 30
  description = "Overwritten or deleted objects can be recovered for this many days (versioning)"
}


variable "gitlab_backup_retention_days" {
  type        = number
  default     = 14
  description = "Daily gitlab-backup archives in the backups bucket are deleted after this many days"
}

variable "gitlab_buckets_force_destroy" {
  type        = bool
  default     = false
  description = "Let `terraform destroy` delete the GitLab buckets even when they still hold objects"
}
