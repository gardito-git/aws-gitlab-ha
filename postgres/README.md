# PostgreSQL (Patroni)

Three PostgreSQL 17 nodes managed by Patroni, with an internal NLB that
always points at the current primary. It holds GitLab's database
(`gitlabhq_production`) and Praefect's (`praefect_production`).

If you have existing/dedicated Postgres, just create database to saving cost. But if your CEO/CTO want to separate things, then maybe this is help.

| | Default |
|---|---|
| Nodes | `postgres-1..3`, one per AZ |
| Instance | `r8i.large` (2 vCPU, 16 GiB), 100 GiB gp3 |
| Endpoint | `<nlb dns>:5432`, always the primary |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `nlb.tf` | Internal NLB on 5432, its target group and security group |
| `security-groups.tf` | PostgreSQL, Patroni and Consul-agent ports |
| `iam.tf` | Read its secrets and the Consul gossip key; `ec2:DescribeInstances` for Consul auto-join |
| `secret-manager.tf` | Three secrets: `admin`, `gitlab-db`, `praefect-db` |
| `scripts/user-data.sh.tftpl` | Installs the Consul agent, PostgreSQL from PGDG, Patroni (pip venv) and postgres_exporter |

## How it works

- Each node runs a **local Consul agent**. Patroni talks to it (`127.0.0.1:8500`)
  to hold or watch the leader lock.
- **First boot:** the first node to take the lock runs `initdb`, then
  Patroni's `post_bootstrap` hook (`/etc/patroni/post-bootstrap.sh`) creates:
  - the users `gitlab`, `praefect` and `postgres_exporter`;
  - both databases;
  - the extensions GitLab needs: `pg_trgm`, `btree_gist` and `plpgsql`.

  The other nodes clone the primary and stream from it.
- **NLB instead of PgBouncer/HAProxy.** The target group forwards port 5432
  but health-checks `GET :8008/primary`, which only the Patroni leader answers
  with 200. After a failover, the new leader turns healthy and the old one's
  connections are cut (`enable_unhealthy_connection_termination`), so clients
  reconnect to the new primary. This takes about 20–30 s.
- **No connection pooling**, so `max_connections = 500`. TCP keepalives and a
  3600 s NLB idle timeout keep Rails' pooled connections alive.
- Cluster-wide settings live in Consul after the first start. Change them with
  `patronictl edit-config`, not by editing the script.

## Secrets

| Secret | Contains | Readable by |
|---|---|---|
| `.../postgres/admin` | superuser, replication, rewind, patroni_api, exporter | postgres only |
| `.../postgres/gitlab-db` | password of user `gitlab` | postgres, rails, sidekiq |
| `.../postgres/praefect-db` | password of user `praefect` | postgres, praefect |

## Ports

| Port | From | Purpose |
|---|---|---|
| 5432 | NLB, peers | PostgreSQL, replication |
| 8008 | NLB, peers, monitoring | Patroni REST API (health check, metrics) |
| 8301/tcp+udp | consul, peers | Consul agent gossip |
| 9187 | monitoring | postgres_exporter |
| 22, 9100 | VPN, monitoring | SSH, node_exporter |

The NLB itself accepts 5432 only from `client_security_group_ids` (rails, sidekiq, praefect).

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base`, `node_count`, `instance_type`, `volume_size` | Shared settings and size |
| `postgres_version` (17), `max_connections` (500) | Database settings |
| `consul_security_group_id`, `consul_join_tag`, `consul_gossip_secret_arn` | From the consul module |
| `client_security_group_ids` | Who may use the NLB |
| `monitoring_security_group_id` | Allowed to scrape metrics |

| Output | Used by |
|---|---|
| `endpoint` | rails, sidekiq, praefect |
| `gitlab_db_secret_arn` | rails, sidekiq |
| `praefect_db_secret_arn` | praefect |
| `security_group_id` | consul (agent rules) |

## Check it

```bash
# Who is the leader, and are the replicas streaming?
sudo -u postgres /opt/patroni/bin/patronictl -c /etc/patroni/patroni.yml list
# Failover demo: stop the leader, then run `list` again on another node
sudo systemctl stop patroni
```
