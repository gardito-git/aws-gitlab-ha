# Inputs this module accepts. The root module passes them in (main.tf).

variable "base" {
  type = object({
    project_name          = string
    environment           = string
    region                = string
    vpc_id                = string
    vpc_cidr              = string
    subnet_ids            = list(string)
    ssh_public_key        = string
    vpn_security_group_id = string
  })
  description = "Settings shared by every role module (local.base in the root main.tf)"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets, one node per subnet/AZ (module.vpc.private_subnet_ids)"

  validation {
    condition     = length(var.private_subnet_ids) == 3
    error_message = "Exactly 3 private subnets are needed: one Rails node per AZ."
  }
}

variable "gitlab_version" {
  type        = string
  default     = ""
  description = "GitLab CE package version, e.g. \"18.6.0-ce.0\"; empty = newest"
}

variable "gitlab_domain" {
  type        = string
  description = "e.g. gitlab.example.com; resolves only inside the VPC"
}

variable "route53_public_zone_id" {
  type        = string
  default     = null
  description = "Public zone of gitlab_domain for a real ACM certificate; null = self-signed CA"
}

# Dependencies

variable "postgres_endpoint" {
  type = string
}

variable "gitlab_db_secret_arn" {
  type = string
}

variable "redis_sentinel_hosts" {
  type = list(string)
}

variable "redis_master_name" {
  type = string
}

variable "redis_password_secret_arn" {
  type = string
}

variable "praefect_endpoint" {
  type = string
}

variable "praefect_external_token_secret_arn" {
  type = string
}

variable "object_buckets" {
  type        = map(string)
  description = "GitLab object type (artifacts, lfs, ...) => bucket name"
}

variable "backup_bucket" {
  type = string
}

variable "bucket_arns" {
  type        = list(string)
  description = "Every GitLab bucket (object storage + backups)"
}

variable "prometheus_address" {
  type        = string
  default     = ""
  description = "host:port of Prometheus, for GitLab's built-in metrics charts"
}

variable "monitoring_security_group_id" {
  type        = string
  description = "Monitoring node, allowed to scrape metrics"
}
