# Self-hosted HA GitLab on AWS

GitLab CE in a highly available setup on EC2, across 3 availability zones,
reachable only through AWS Client VPN. One `terraform apply` builds
everything: each node installs and configures itself at first boot
(`user_data`), fetching its passwords from Secrets Manager.

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.5-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-provider%206.x-FF9900?logo=amazonwebservices&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu&logoColor=white)
![Gitlab](https://img.shields.io/badge/Gitlab-18.11.14%20CE-E95420?logo=gitlab&logoColor=white)

```
                       VPN user / runners (inside the VPC)
                                     │
                       gitlab.example.com (private Route 53 zone)
                                     │
                     ┌───────────────▼────────────────┐
                     │ rails NLB (internal)           │  443 TLS (ACM) · 22 TCP
                     └───────────────┬────────────────┘
                          ┌──────────┼──────────┐
                       rails-1    rails-2    rails-3      GitLab Rails (Puma, Workhorse, NGINX)
                          │          │          │         sidekiq-1..3 run background jobs
           ┌──────────────┼──────────┴──────┬───┴─────────────────┐
           │              │                 │                     │
   ┌───────▼───────┐  Redis Sentinel   ┌────▼────────────────┐    S3 (private buckets:
   │ postgres NLB  │  redis-1..3       │ praefect NLB :2305  │    artifacts, lfs, uploads,
   │ :5432         │                   └────┬────────────────┘    packages, backups, ...)
   │ health check: │                  praefect-1..3
   │ Patroni       │                        │ 3 replicas of every repository
   │ GET /primary  │                  gitaly-1..3
   └───────┬───────┘
     postgres-1..3  (Patroni) ◄── leader election ── consul-1..3

   monitoring-1: Prometheus (EC2 discovery) + Grafana     runner-1..6: GitLab Runner, Docker executor
```

## Repository layout

One folder per component. Each holds everything that component needs, plus a README that explains it:

| Folder | Files | What it is |
|---|---|---|
| [vpc/](vpc/README.md) | | VPC over 3 AZs, NAT, S3 endpoint, Client VPN |
| [s3/](s3/README.md) | | Private bucket; GitLab object-storage and backup buckets |
| [consul/](consul/README.md) | compute, security-groups, iam, secret-manager, scripts | 3 Consul servers (Patroni's leader election) |
| [postgres/](postgres/README.md) | compute, **nlb**, security-groups, iam, secret-manager, scripts | 3 × PostgreSQL 17 + Patroni, NLB pointing at the primary |
| [redis/](redis/README.md) | compute, security-groups, iam, secret-manager, scripts | 3 × Redis + Sentinel |
| [gitaly/](gitaly/README.md) | compute, security-groups, iam, scripts | 3 Gitaly storage nodes |
| [praefect/](praefect/README.md) | compute, **nlb**, security-groups, iam, secret-manager, scripts | 3 Praefect routers + NLB |
| [rails/](rails/README.md) | compute, **nlb**, **dns-tls**, security-groups, iam, secret-manager, scripts | 3 GitLab Rails nodes, frontend NLB, private DNS, certificate |
| [sidekiq/](sidekiq/README.md) | compute, security-groups, iam, scripts | 3 Sidekiq nodes |
| [runner/](runner/README.md) | compute, security-groups, iam, scripts | 6 GitLab Runners (Docker executor) |
| [monitoring/](monitoring/README.md) | compute, security-groups, iam, secret-manager, scripts | Prometheus + Grafana |

[main.tf](main.tf) wires the modules together. Each module sets its own size
directly in its `compute.tf` (`count`, `instance_type`, `volume_size`), and
takes the 3 private subnets as `private_subnet_ids`, one node per AZ.

## How the nodes coordinate at first boot

Every node runs `scripts/user-data.sh.tftpl` once (log:
`/var/log/cloud-init-output.log`). The scripts wait for what they depend on,
so all nodes can boot at the same time:

1. **Consul** servers find each other through EC2 tags (cloud auto-join).
2. **PostgreSQL** nodes start Patroni. The first to get the Consul lock
   initialises the cluster, and Patroni's `post_bootstrap` hook creates the
   `gitlab` and `praefect` users and databases.
3. **Redis**: `redis-1` starts as primary, the others replicate it, and Sentinel takes over from there.
4. **Gitaly** starts. **Praefect** waits for PostgreSQL, then `praefect-1` migrates its schema.
5. **rails-1** waits for PostgreSQL and Redis, runs the migrations, then:
   - publishes `gitlab-secrets.json` to Secrets Manager;
   - creates the instance runner and publishes its token;
   - installs the daily backup cron job.
6. **rails-2/3 and Sidekiq** wait for `gitlab-secrets.json`, then join.
   **Runners** wait for the runner token and for GitLab to answer, then register.
7. **Prometheus** discovers every node by its `Role` tag.

Expect roughly 20–30 minutes until GitLab answers.

## Design decisions

| Decision | Why |
|---|---|
| **NLB instead of ALB or Nginx** in front of GitLab | GitLab needs SSH (port 22) for `git clone git@...`, which an ALB cannot carry. One managed NLB handles HTTPS and SSH with no instance to keep alive. |
| **NLB with a Patroni health check instead of PgBouncer + HAProxy** | The NLB forwards port 5432 but checks `GET :8008/primary`. Only the Patroni leader answers 200, so writes always reach the primary. The trade-offs are no connection pooling (so `max_connections` is 500 and Sidekiq concurrency is kept modest) and about 20–30 s of failover. |
| **Praefect behind its own NLB** | This replaces the single HAProxy node, which was a single point of failure. |
| **user_data instead of Ansible** | Each module is self-contained, and one `terraform apply` builds the whole cluster. Scripts run once; to re-provision a node, replace it (see below). |
| **Secrets in Secrets Manager, read at boot** | Passwords are never in `user_data`, which anyone with EC2 read access can see. Each module owns its secrets, and other modules' roles get read access to only the ones they need. |
| **Consul, Patroni, PostgreSQL and Redis from upstream packages** | The GitLab CE package does not ship the Patroni/Consul HA setup (GitLab documents it as a Premium feature). As "external" services, they are fully supported by CE. |
| **Private S3 buckets, one per object type** | This is GitLab's recommendation. Downloads are proxied by GitLab, so clients never talk to S3. |
| **VPN only, self-signed CA by default** | All NLBs are internal, and `gitlab.example.com` exists only in a private zone. Set `route53_public_zone_id` for a real certificate on a domain you own. |

> **Cost:** roughly **$3.3k–3.6k/month (about $4.70/hour)** if left running,
> plus three NLBs, EBS, NAT and data transfer. That is an estimate for
> us-east-1 on-demand pricing, so check the AWS Pricing Calculator. For a
> portfolio, build it, take your screenshots, then `terraform destroy`.

## Deploy

1. Create `terraform.tfvars`:

   ```hcl
   project_name     = "gitlab-ha"
   vpn_client_names = ["user"]
   ssh_public_key   = "ssh-ed25519 AAAA... you@laptop"
   # gitlab_domain  = "gitlab.example.com"   # default
   # gitlab_version = "18.6.0-ce.0"          # pin so every node gets the same version
   # gitlab_buckets_force_destroy = true     # handy for a throwaway demo
   ```

2. Apply:

   ```powershell
   terraform init
   ```

   ```powershell
   terraform apply
   ```

3. Connect the VPN:

   ```powershell
   terraform output -json vpn_client_configs | jq -r '.user' > user.ovpn
   ```

   Import `user.ovpn` into OpenVPN Connect and connect.

4. Trust the CA (only needed with the self-signed default):

   ```powershell
   terraform output -raw gitlab_ca_cert > gitlab-ca.crt
   ```

   ```powershell
   Import-Certificate -FilePath gitlab-ca.crt -CertStoreLocation Cert:\CurrentUser\Root
   ```

5. Log in at https://gitlab.example.com as `root`. To get the password:

   ```powershell
   aws secretsmanager get-secret-value --secret-id (terraform output -raw gitlab_root_password_secret_arn) --query SecretString --output text
   ```

6. For Git over SSH, add `gitlab.example.com <terraform output -raw gitlab_git_ssh_host_key>` to `~/.ssh/known_hosts`.

| Service | URL (over VPN) | Login |
|---|---|---|
| GitLab | https://gitlab.example.com | `root` / `gitlab_root_password_secret_arn` |
| Grafana | `terraform output grafana_url` | `admin` / `grafana_admin_secret_arn` |
| Prometheus | `terraform output prometheus_url` | none |
| Consul UI | `terraform output consul_ui_url` | none |

To follow a node's first boot:

```bash
ssh ubuntu@<ip> sudo tail -f /var/log/cloud-init-output.log
```

## Re-provisioning a node

Scripts run only at first boot, and Terraform ignores later edits to them, so
running nodes are never rebuilt by accident. To rebuild one on purpose:

```powershell
terraform apply -replace='module.rails.aws_instance.this[\"rails-2\"]'
```

## Backups

`rails-1` runs `gitlab-backup create` every day at **00:00 UTC**. It uploads
the database and every repository to the `...-gitlab-backups-...` bucket, and
an S3 lifecycle rule deletes archives after `gitlab_backup_retention_days`
(default 14).

Object storage (artifacts, LFS, uploads) is not in the backup, but those
buckets are versioned.

**A backup can only be restored with the same `gitlab-secrets.json`.** It is
kept in the secret behind `terraform output gitlab_secrets_json_secret_arn`,
so keep a copy outside this AWS account too.

## Checking HA (good screenshots)

```bash
# PostgreSQL: who is the leader? Then stop it and watch the failover.
ssh ubuntu@<postgres ip> sudo -u postgres /opt/patroni/bin/patronictl -c /etc/patroni/patroni.yml list
ssh ubuntu@<leader ip> sudo systemctl stop patroni

# Gitaly Cluster: Praefect can reach all Gitaly nodes
ssh ubuntu@<praefect ip> sudo /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml dial-nodes

# Redis: who is primary?
ssh ubuntu@<redis ip> redis-cli -p 26379 sentinel get-master-addr-by-name gitlab-redis

# GitLab's own checks
ssh ubuntu@<rails-1 ip> sudo gitlab-rake gitlab:check SANITIZE=true
```

## Teardown

```powershell
terraform destroy
```

Non-empty GitLab buckets block the destroy unless `gitlab_buckets_force_destroy = true`.
