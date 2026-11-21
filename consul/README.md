# Consul

Three Consul servers. Patroni ([../postgres](../postgres/README.md)) uses them
as its leader-election store: whoever holds the Consul lock is the PostgreSQL
primary. Nothing else in the cluster uses Consul.

Sizes are set directly in `compute.tf` (`count`, `instance_type`, `volume_size`).

| | Value |
|---|---|
| Nodes | `consul-1..3`, one per AZ |
| Instance | `c8i.large`, 30 GiB gp3 |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `security-groups.tf` | Consul ports between servers and agents, SSH from the VPN, metrics |
| `iam.tf` | Read the gossip key; `ec2:DescribeInstances` for cloud auto-join |
| `secret-manager.tf` | Gossip encryption key |
| `scripts/user-data.sh.tftpl` | Installs Consul from HashiCorp's apt repo and starts it as a server |

## How it works

- Servers and agents find each other through **cloud auto-join**. Every server
  is tagged `ConsulJoin = gitlab-<project>-<env>`, and `retry_join` searches EC2 for that tag,
  so no IP addresses are hard-coded.
- Gossip traffic is encrypted with the key from `secret-manager.tf`. The
  PostgreSQL agents read the same key.
- `bootstrap_expect = 3` (the instance `count`), so the servers elect a leader once all of them are up.

## Ports

| Port | From | Purpose |
|---|---|---|
| 8300/tcp | servers, agents | Server RPC |
| 8301/tcp+udp | servers, agents | LAN gossip |
| 8500/tcp | VPN, monitoring | HTTP API, UI, Prometheus metrics |
| 22, 9100 | VPN, monitoring | SSH, node_exporter |

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base` | Shared settings (VPC, subnets, SSH key, VPN group) |
| `private_subnet_ids` | Exactly 3 private subnets; nodes go one per subnet/AZ |
| `monitoring_security_group_id` | Allowed to scrape metrics |
| `agent_security_group_ids` | Groups running agents, e.g. `{ postgres = ... }` |

| Output | Used by |
|---|---|
| `join_tag`, `gossip_secret_arn`, `security_group_id` | postgres (its agents) |
| `private_ips` | Root outputs (Consul UI URL) |

## Check it

```bash
ssh ubuntu@<consul ip> consul members          # servers + the postgres agents
```

The UI is at `http://<consul-1 ip>:8500` over the VPN.
