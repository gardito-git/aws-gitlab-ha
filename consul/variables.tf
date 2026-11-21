# Inputs this module accepts. The root module passes them in (main.tf).

variable "base" {
  type = object({
    project_name          = string
    environment           = string
    region                = string
    vpc_id                = string
    vpc_cidr              = string
    subnet_ids            = list(string) # one private subnet per AZ, in AZ order
    ssh_public_key        = string
    vpn_security_group_id = string
  })
  description = "Settings shared by every role module (local.base in the root main.tf)"
}

variable "node_count" {
  type        = number
  default     = 3
  description = "Consul servers. Keep it odd (3 or 5) so they can always elect a leader."
}

variable "instance_type" {
  type    = string
  default = "c8i.large"
}

variable "volume_size" {
  type        = number
  default     = 30
  description = "Root volume size in GiB (gp3)"
}

variable "monitoring_security_group_id" {
  type        = string
  description = "Monitoring node, allowed to scrape metrics"
}

variable "agent_security_group_ids" {
  type        = map(string)
  default     = {}
  description = "Groups running Consul agents that join this cluster, e.g. { postgres = <sg id> }"
}
