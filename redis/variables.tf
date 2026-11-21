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
  type        = number
  default     = 3
  description = "Redis nodes, each with a Sentinel. Keep 3+ so Sentinels can reach a quorum."
}

variable "instance_type" {
  type    = string
  default = "r8i.large"
}

variable "volume_size" {
  type    = number
  default = 50
}

variable "master_name" {
  type        = string
  default     = "gitlab-redis"
  description = "Name the Sentinels monitor; GitLab asks for the primary by this name"
}

variable "monitoring_security_group_id" {
  type        = string
  description = "Monitoring node, allowed to scrape metrics"
}

variable "client_security_group_ids" {
  type        = map(string)
  default     = {}
  description = "Who may use Redis/Sentinel, e.g. { rails = <sg>, sidekiq = <sg> }"
}
