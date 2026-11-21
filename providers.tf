terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Generates passwords
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    # VPN certificates, GitLab's self-signed CA and the Git SSH host key.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # For Ansible
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  # Credentials come from the default AWS chain (env vars, ~/.aws, SSO).
  # Add profile = "<name>" here only if you use a named profile.
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
