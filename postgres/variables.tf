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
  default = "r8i.large"
}

variable "volume_size" {
  type        = number
  default     = 100
  description = "Root volume size in GiB (gp3); holds the database"
}

variable "postgres_version" {
  type    = number
  default = 17
}

variable "max_connections" {
  type        = number
  default     = 500
  description = "No PgBouncer: every Rails/Sidekiq/Praefect connection is a PostgreSQL connection"
}

variable "monitoring_security_group_id" {
  type        = string
  description = "Monitoring node, allowed to scrape metrics"
}

variable "consul_security_group_id" {
  type        = string
  description = "Consul servers (gossip with the local agents)"
}

variable "consul_join_tag" {
  type        = string
  description = "Tag value the Consul servers carry (cloud auto-join)"
}

variable "consul_gossip_secret_arn" {
  type = string
}

variable "client_security_group_ids" {
  type        = map(string)
  default     = {}
  description = "Who may connect through the NLB, e.g. { rails = <sg>, sidekiq = <sg>, praefect = <sg> }"
}
