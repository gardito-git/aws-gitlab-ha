# Sidekiq

Three Sidekiq nodes that run GitLab's background jobs: CI pipeline
processing, emails, webhooks, repository housekeeping and more. They use the
same database, Redis, Gitaly and S3 as Rails, but serve no web traffic.

| | Default |
|---|---|
| Nodes | `sidekiq-1..3`, one per AZ |
| Instance | `m8i.large`, 50 GiB gp3 |
| Processes | One per vCPU, each with `max_concurrency = 10` threads, all queues |
| Software | GitLab CE package, with only Sidekiq enabled |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `security-groups.tf` | SSH from the VPN, metrics |
| `iam.tf` | S3 object storage; read the secrets it needs |
| `scripts/user-data.sh.tftpl` | Writes `gitlab.rb`, installs `gitlab-ce`, waits for `gitlab-secrets.json`, reconfigures |

There is no `secret-manager.tf`: every secret Sidekiq uses belongs to another
module (rails, postgres, redis, praefect).

## How it works

- **Waits for rails-1.** Sidekiq waits until rails-1 has published
  `gitlab-secrets.json`, which happens after the database migrations. It then
  installs that file and reconfigures, so its encryption keys match Rails'.
- **Concurrency is kept modest.** There is no PgBouncer, so every Sidekiq
  thread holds real PostgreSQL connections. Raise `max_concurrency` only
  together with PostgreSQL's `max_connections`.
- **Talks to nobody inbound.** Sidekiq only makes outbound connections, so its
  security group only opens SSH and metrics.

## Ports

| Port | From | Purpose |
|---|---|---|
| 8082 | monitoring | Sidekiq metrics |
| 22, 9100 | VPN, monitoring | SSH, node_exporter |

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base`, `node_count`, `instance_type`, `volume_size` | Shared settings and size |
| `max_concurrency`, `gitlab_version` | Sidekiq settings |
| `gitlab_url`, `gitlab_ca_cert`, `gitlab_shell_secret_arn`, `gitlab_secrets_json_secret_arn` | From rails |
| `postgres_endpoint`, `gitlab_db_secret_arn` | From postgres |
| `redis_sentinel_hosts`, `redis_master_name`, `redis_password_secret_arn` | From redis |
| `praefect_endpoint`, `praefect_external_token_secret_arn` | From praefect |
| `object_buckets`, `bucket_arns` | From s3 |
| `monitoring_security_group_id` | Allowed to scrape metrics |

| Output | Used by |
|---|---|
| `security_group_id` | postgres, redis, praefect (client rules) |
| `private_ips` | Root outputs |

## Check it

```bash
sudo gitlab-ctl status sidekiq
sudo gitlab-ctl tail sidekiq
```

In GitLab: **Admin → Monitoring → Background jobs** shows the queues and processes.
