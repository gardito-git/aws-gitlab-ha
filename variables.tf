variable "region" {
  default     = "us-east-1" # Please update your AMI data sources if you change this.
  type        = string
  description = "AWS region to deploy into"
}

variable "project_name" {
  default     = "example" #  TO-DO
  type        = string
  description = "Project name used in tags and resource names"
}

variable "environment" {
  default     = "dev"
  type        = string
  description = "Deployment environment: dev, staging, beta, uat, live or production"

  # Rejects typos like "prod" or "Dev" at plan time instead of tagging them.
  validation {
    condition     = contains(["dev", "staging", "beta", "uat", "live", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, beta, uat, live, production."
  }
}

variable "vpn_client_names" {
  type        = set(string)
  default     = ["admin"]
  description = "People who get a VPN profile, e.g. [\"gardito\", \"alice\"]"
}

variable "ssh_public_key" {
  type        = string
  description = "Your SSH public key (contents of ~/.ssh/id_ed25519.pub), installed on every node for user \"ubuntu\""

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) ", var.ssh_public_key))
    error_message = "ssh_public_key must be a public key line starting with ssh-ed25519, ssh-rsa or ecdsa-sha2-*. Never the private key."
  }
}

variable "gitlab_domain" {
  type        = string
  default     = "gitlab.example.com"
  description = "GitLab hostname. Resolves only inside the VPC (private Route 53 zone), i.e. over the VPN."
}

variable "route53_public_zone_id" {
  type        = string
  default     = null
  description = "Public Route 53 zone of gitlab_domain for a real ACM certificate. Leave null to use a self-signed CA (fine for gitlab.example.com)."
}

variable "gitlab_backup_retention_days" {
  type        = number
  default     = 14
  description = "Daily GitLab backups in S3 are deleted after this many days"
}

variable "gitlab_buckets_force_destroy" {
  type        = bool
  default     = false
  description = "Let `terraform destroy` delete non-empty GitLab buckets. true is handy for a throwaway demo."
}

variable "gitlab_version" {
  type        = string
  default     = ""
  # default     = "18.11.14-ce" # pin it to avoid nodes drifting apart
  description = "GitLab CE package version for every GitLab node, e.g. \"18.6.0-ce.0\". Empty = newest at first boot; pin it so all nodes match."
}
