# Root module: run terraform from this folder. Each folder is one module with
# its own compute, security groups, IAM, secrets and load balancer (where it
# has one); its scripts/ install the software at first boot. This file wires
# one module's outputs into the next module's inputs.
#
#   consul ◄── postgres ◄─┬─ praefect ◄── gitaly
#                         │      ▲
#   redis ◄───────────────┼─ rails ◄── sidekiq, runner
#                         │      ▲
#   s3 ───────────────────┘      └── (every role) ──► monitoring

module "vpc" {
  source = "./vpc"

  region       = var.region
  project_name = var.project_name
  environment  = var.environment

  vpn_client_names = var.vpn_client_names
}

module "s3" {
  source = "./s3"

  project_name = var.project_name
  environment  = var.environment

  gitlab_backup_retention_days = var.gitlab_backup_retention_days
  gitlab_buckets_force_destroy = var.gitlab_buckets_force_destroy
}

locals {
  # Passed to every role module.
  base = {
    project_name          = var.project_name
    environment           = var.environment
    region                = var.region
    vpc_id                = module.vpc.vpc_id
    vpc_cidr              = module.vpc.vpc_cidr
    subnet_ids            = module.vpc.private_subnet_ids
    ssh_public_key        = var.ssh_public_key
    vpn_security_group_id = module.vpc.vpn_security_group_id
  }

  monitoring_sg = module.monitoring.security_group_id
}

# Data layer

module "consul" {
  source = "./consul"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  monitoring_security_group_id = local.monitoring_sg
  agent_security_group_ids     = { postgres = module.postgres.security_group_id }
}

module "postgres" {
  source = "./postgres"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  monitoring_security_group_id = local.monitoring_sg
  consul_security_group_id     = module.consul.security_group_id
  consul_join_tag              = module.consul.join_tag
  consul_gossip_secret_arn     = module.consul.gossip_secret_arn

  client_security_group_ids = {
    rails    = module.rails.security_group_id
    sidekiq  = module.sidekiq.security_group_id
    praefect = module.praefect.security_group_id
  }
}

module "redis" {
  source = "./redis"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  monitoring_security_group_id = local.monitoring_sg
  client_security_group_ids = {
    rails   = module.rails.security_group_id
    sidekiq = module.sidekiq.security_group_id
  }
}

# Gitaly Cluster

module "praefect" {
  source = "./praefect"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  gitlab_version               = var.gitlab_version
  monitoring_security_group_id = local.monitoring_sg
  gitaly_storages              = module.gitaly.storages
  postgres_endpoint            = module.postgres.endpoint
  praefect_db_secret_arn       = module.postgres.praefect_db_secret_arn

  client_security_group_ids = {
    rails   = module.rails.security_group_id
    sidekiq = module.sidekiq.security_group_id
  }
}

module "gitaly" {
  source = "./gitaly"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  gitlab_version                     = var.gitlab_version
  monitoring_security_group_id       = local.monitoring_sg
  praefect_security_group_id         = module.praefect.security_group_id
  praefect_internal_token_secret_arn = module.praefect.internal_token_secret_arn
  gitlab_url                         = module.rails.gitlab_url
  gitlab_ca_cert                     = module.rails.gitlab_ca_cert
  gitlab_shell_secret_arn            = module.rails.gitlab_shell_secret_arn
}

# GitLab application

module "rails" {
  source = "./rails"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  gitlab_version               = var.gitlab_version
  gitlab_domain                = var.gitlab_domain
  route53_public_zone_id       = var.route53_public_zone_id
  monitoring_security_group_id = local.monitoring_sg
  prometheus_address           = module.monitoring.prometheus_address

  postgres_endpoint                  = module.postgres.endpoint
  gitlab_db_secret_arn               = module.postgres.gitlab_db_secret_arn
  redis_sentinel_hosts               = module.redis.sentinel_hosts
  redis_master_name                  = module.redis.master_name
  redis_password_secret_arn          = module.redis.password_secret_arn
  praefect_endpoint                  = module.praefect.endpoint
  praefect_external_token_secret_arn = module.praefect.external_token_secret_arn

  object_buckets = module.s3.gitlab_object_buckets
  backup_bucket  = module.s3.gitlab_backup_bucket
  bucket_arns    = module.s3.gitlab_bucket_arns
}

module "sidekiq" {
  source = "./sidekiq"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  gitlab_version               = var.gitlab_version
  monitoring_security_group_id = local.monitoring_sg

  gitlab_url                     = module.rails.gitlab_url
  gitlab_ca_cert                 = module.rails.gitlab_ca_cert
  gitlab_shell_secret_arn        = module.rails.gitlab_shell_secret_arn
  gitlab_secrets_json_secret_arn = module.rails.gitlab_secrets_json_secret_arn

  postgres_endpoint                  = module.postgres.endpoint
  gitlab_db_secret_arn               = module.postgres.gitlab_db_secret_arn
  redis_sentinel_hosts               = module.redis.sentinel_hosts
  redis_master_name                  = module.redis.master_name
  redis_password_secret_arn          = module.redis.password_secret_arn
  praefect_endpoint                  = module.praefect.endpoint
  praefect_external_token_secret_arn = module.praefect.external_token_secret_arn

  object_buckets = module.s3.gitlab_object_buckets
  bucket_arns    = module.s3.gitlab_bucket_arns
}

module "runner" {
  source = "./runner"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids

  monitoring_security_group_id = local.monitoring_sg
  gitlab_url                   = module.rails.gitlab_url
  gitlab_ca_cert               = module.rails.gitlab_ca_cert
  runner_token_secret_arn      = module.rails.runner_token_secret_arn
}

# Monitoring (finds every node through EC2 tags; depends on no other role)

module "monitoring" {
  source = "./monitoring"
  base   = local.base

  private_subnet_ids = module.vpc.private_subnet_ids
}
