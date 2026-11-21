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

variable "node_count" {
  type    = number
  default = 6
}

variable "instance_type" {
  type    = string
  default = "c8i.xlarge"
}

variable "volume_size" {
  type        = number
  default     = 100
  description = "Root volume size in GiB (gp3); holds Docker images and build caches"
}

variable "concurrent" {
  type        = number
  default     = 4
  description = "CI jobs at once per runner machine (c8i.xlarge = 4 vCPU)"
}

variable "default_image" {
  type        = string
  default     = "alpine:latest"
  description = "Image for jobs that don't set one"
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
