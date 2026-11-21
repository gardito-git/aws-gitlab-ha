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
    error_message = "Exactly 3 private subnets are needed: the 6 runners are spread 2 per AZ."
  }
}

variable "gitlab_url" {
  type = string
}

variable "gitlab_ca_cert" {
  type        = string
  default     = ""
  description = "CA of GitLab's certificate when self-signed; empty for a public certificate"
}

variable "runner_token_secret_arn" {
  type        = string
  description = "Filled in by rails-1 once GitLab is up (from the rails module)"
}

variable "monitoring_security_group_id" {
  type        = string
  description = "Monitoring node, allowed to scrape metrics"
}
