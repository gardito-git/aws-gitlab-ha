# Redis + Sentinel

Three Redis nodes (one primary, two replicas), with a Sentinel on each. GitLab
asks the Sentinels which node is the primary, so a failover needs no config
change on the GitLab side.

Highly recommended use existing Redis Sentinel/Cluster for saving cost.

| | Default |
|---|---|
| Nodes | `redis-1..3`, one per AZ |
| Instance | `r8i.large`, 50 GiB gp3 |
| Sentinel master name | `gitlab-redis` |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | Network interfaces, EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `security-groups.tf` | Redis and Sentinel ports, SSH, metrics |
| `iam.tf` | Read the Redis password |
| `secret-manager.tf` | Redis password (`requirepass` / `masterauth`) |
| `scripts/user-data.sh.tftpl` | Installs redis-server, redis-sentinel and redis_exporter from Ubuntu |

## How it works

- Each node's **network interface is created before the instance**, so its IP
  is known up front. That lets every script be rendered with `redis-1`'s address
  (the initial primary), and lets GitLab get a fixed list of Sentinels.
- `redis-1` starts as primary and the others start with `replicaof redis-1`. After
  that, Sentinel is in charge: a quorum of 2 promotes a replica when the
  primary has been down for 10 s.
- Redis and Sentinel **rewrite their own config files** after a failover. The
  script writes them only once, at first boot, so nothing ever puts the old
  topology back.
- Persistence: RDB snapshots plus AOF (`appendonly yes`).

## Ports

| Port | From | Purpose |
|---|---|---|
| 6379 | rails, sidekiq, peers | Redis |
| 26379 | rails, sidekiq, peers | Sentinel |
| 9121 | monitoring | redis_exporter |
| 22, 9100 | VPN, monitoring | SSH, node_exporter |

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base`, `node_count`, `instance_type`, `volume_size` | Shared settings and size (keep 3+ nodes) |
| `master_name` | Name the Sentinels monitor |
| `client_security_group_ids` | Who may connect, e.g. `{ rails, sidekiq }` |
| `monitoring_security_group_id` | Allowed to scrape metrics |

| Output | Used by |
|---|---|
| `sentinel_hosts`, `master_name`, `password_secret_arn` | rails, sidekiq |
| `private_ips` | Root outputs |

## Check it

```bash
redis-cli -p 26379 sentinel get-master-addr-by-name gitlab-redis    # current primary
redis-cli -a "$(sudo grep ^requirepass /etc/redis/redis.conf | cut -d' ' -f2)" info replication
# Failover demo: stop Redis on the primary and ask the Sentinels again
sudo systemctl stop redis-server
```
