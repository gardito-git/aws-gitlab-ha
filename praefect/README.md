# Praefect

Three Praefect nodes behind an internal NLB. Together with
[../gitaly](../gitaly/README.md) they form Gitaly Cluster: Rails and Sidekiq
send every Git operation to Praefect, which routes it to Gitaly and keeps
3 replicas of every repository. If a Gitaly node dies, Praefect fails over to
another replica.

Sizes are set directly in `compute.tf` (`count`, `instance_type`, `volume_size`).

| | Value |
|---|---|
| Nodes | `praefect-1..3`, one per AZ |
| Instance | `c8i.large`, 30 GiB gp3 |
| Endpoint | `tcp://<nlb dns>:2305` |
| Database | `praefect_production` on the PostgreSQL cluster |
| Software | GitLab CE package, with only Praefect enabled |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `nlb.tf` | Internal NLB on 2305, its target group and security group |
| `security-groups.tf` | Praefect port from the NLB, SSH, metrics |
| `iam.tf` | Read both tokens and the praefect DB password |
| `secret-manager.tf` | `external-token` (GitLab → Praefect) and `internal-token` (Praefect → Gitaly) |
| `scripts/user-data.sh.tftpl` | Writes `gitlab.rb` with the Gitaly addresses, installs `gitlab-ce`, waits for PostgreSQL, reconfigures |

## How it works

- **Gitaly addresses:** the `virtual_storage` called `default` lists every
  Gitaly node (from the gitaly module's `storages` output), with
  `default_replication_factor` = the number of Gitaly nodes.
- **Database:** Praefect connects straight to the PostgreSQL NLB.
  GitLab says Praefect must not sit behind a transaction-pooling PgBouncer
  anyway. The database and user are created when the PostgreSQL cluster
  bootstraps.
- **Schema migrations:** `praefect-1` runs them (`praefect['auto_migrate'] = true`).
  `gitlab-ctl reconfigure` is retried until the database is reachable.
- **NLB idle timeout:** 3600 s, so long-lived gRPC connections aren't dropped.

## Ports

| Port | From | Purpose |
|---|---|---|
| 2305 | NLB | Praefect gRPC |
| 9652 | monitoring | Praefect metrics |
| 22, 9100 | VPN, monitoring | SSH, node_exporter |

The NLB itself accepts 2305 only from `client_security_group_ids` (rails, sidekiq).

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base` | Shared settings (VPC, region, SSH key, VPN group) |
| `private_subnet_ids` | Exactly 3 private subnets; nodes go one per subnet/AZ |
| `gitlab_version` | GitLab CE package version (empty = newest) |
| `gitaly_storages` | From the gitaly module |
| `postgres_endpoint`, `praefect_db_secret_arn` | From the postgres module |
| `client_security_group_ids` | Who may use the NLB |
| `monitoring_security_group_id` | Allowed to scrape metrics |

| Output | Used by |
|---|---|
| `endpoint`, `external_token_secret_arn` | rails, sidekiq |
| `internal_token_secret_arn`, `security_group_id` | gitaly |

## Check it

```bash
# Can Praefect reach every Gitaly node and its database?
sudo /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml dial-nodes
sudo /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml sql-ping
```
