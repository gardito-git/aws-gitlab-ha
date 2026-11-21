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
  default = 3
}

variable "instance_type" {
  type    = string
  default = "c8i.large"
}

variable "volume_size" {
  type    = number
  default = 30
}

variable "gitlab_version" {
  type        = string
  default     = ""
  description = "GitLab CE package version, e.g. \"18.6.0-ce.0\"; empty = newest"
}

variable "gitaly_storages" {
  type        = map(string)
  description = "Gitaly storage name => IP (from the gitaly module)"
}

variable "postgres_endpoint" {
  type        = string
  description = "PostgreSQL primary (NLB host name, port 5432)"
}

variable "praefect_db_secret_arn" {
  type        = string
  description = "Password of PostgreSQL user praefect (from the postgres module)"
}

variable "client_security_group_ids" {
  type        = map(string)
  default     = {}
  description = "Who may use Praefect through the NLB, e.g. { rails = <sg>, sidekiq = <sg> }"
}

variable "monitoring_security_group_id" {
  type        = string
  description = "Monitoring node, allowed to scrape metrics"
}
