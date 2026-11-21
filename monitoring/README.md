# Monitoring

One node running Prometheus and Grafana. Prometheus scrapes every node of
the cluster; Grafana shows it. Both are reachable over the VPN only.

| | Default |
|---|---|
| Node | `monitoring-1`, AZ a |
| Instance | `r8i.xlarge`, 100 GiB gp3 for Prometheus data |
| Retention | 15 days |
| Grafana | `http://<ip>:3000`, user `admin` |
| Prometheus | `http://<ip>:9090` |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | EC2 node, key pair, Ubuntu 24.04 AMI, the list of scrape jobs |
| `security-groups.tf` | Grafana, Prometheus and SSH from the VPN |
| `iam.tf` | Read the Grafana password; `ec2:DescribeInstances` for service discovery |
| `secret-manager.tf` | Grafana admin password |
| `scripts/user-data.sh.tftpl` | Installs Prometheus (Ubuntu) and Grafana (official repo); provisions the data source and a dashboard |

## How it works

- **EC2 service discovery.** Prometheus asks EC2 for running instances tagged
  with this project and environment, then picks targets by their `Role` tag.
  Rebuilt or added nodes show up by themselves, and this module depends on no
  other role module.
- **Every other module** allows this node's security group on its metrics
  ports. That's why they all take `monitoring_security_group_id`.
- **Grafana:**
  - Prometheus is provisioned as the default data source.
  - The *Node Exporter Full* dashboard (grafana.com ID 1860) is pre-loaded.
  - The admin password is applied on Grafana's first start only.

## What is scraped

| Job | Role tag | Port |
|---|---|---|
| node | every node | 9100 |
| consul | consul | 8500 (`/v1/agent/metrics`) |
| patroni, postgres | postgres | 8008, 9187 |
| redis | redis | 9121 |
| gitaly | gitaly | 9236 |
| praefect | praefect | 9652 |
| gitlab-rails, gitlab-workhorse, puma, gitlab-exporter | rails | 80 (`/-/metrics`), 9229, 8083, 9168 |
| sidekiq | sidekiq | 8082 |
| gitlab-runner | runner | 9252 |

To add a job, add a line to `local.scrape_jobs` in `compute.tf`. A running node
keeps its first-boot config, so replace the node or edit
`/etc/prometheus/prometheus.yml` on it.

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base`, `instance_type`, `volume_size` | Shared settings and size |
| `retention` | How long Prometheus keeps data |

| Output | Used by |
|---|---|
| `security_group_id` | Every other role module |
| `prometheus_address` | rails (GitLab's built-in metrics charts) |
| `grafana_url`, `prometheus_url`, `grafana_admin_secret_arn` | Root outputs, for you |

## Check it

- Open **Status → Targets** in Prometheus: every target should be `UP`.
- Grafana's admin password:

  ```powershell
  aws secretsmanager get-secret-value --secret-id (terraform output -raw grafana_admin_secret_arn) --query SecretString --output text
  ```
