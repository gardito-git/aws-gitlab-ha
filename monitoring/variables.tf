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

variable "instance_type" {
  type    = string
  default = "r8i.xlarge"
}

variable "volume_size" {
  type        = number
  default     = 100
  description = "Root volume size in GiB (gp3); holds Prometheus data"
}

variable "retention" {
  type        = string
  default     = "15d"
  description = "How long Prometheus keeps metrics"
}
