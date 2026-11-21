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
    error_message = "Exactly 3 private subnets are needed: one Gitaly node (one copy of every repository) per AZ."
  }
}

variable "gitlab_version" {
  type        = string
  default     = ""
  description = "GitLab CE package version, e.g. \"18.6.0-ce.0\"; empty = newest"
}

variable "gitlab_url" {
  type        = string
  description = "Git hooks call GitLab's internal API here"
}

variable "gitlab_ca_cert" {
  type        = string
  default     = ""
  description = "CA of GitLab's certificate when self-signed; empty for a public certificate"
}

variable "gitlab_shell_secret_arn" {
  type        = string
  description = "gitlab-shell secret token (from the rails module)"
}

variable "praefect_internal_token_secret_arn" {
  type        = string
  description = "Token Praefect uses to talk to Gitaly (from the praefect module)"
}

variable "praefect_security_group_id" {
  type = string
}

variable "monitoring_security_group_id" {
  type        = string
  description = "Monitoring node, allowed to scrape metrics"
}
