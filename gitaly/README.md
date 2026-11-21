# Gitaly

Three Gitaly nodes that store the Git repositories. Only Praefect
([../praefect](../praefect/README.md)) talks to them, and it keeps a full copy
of every repository on each node.

| | Default |
|---|---|
| Nodes | `gitaly-1..3`, one per AZ; also their storage names |
| Instance | `m8i.large`, 200 GiB gp3 (repositories live on the root volume) |
| Software | GitLab CE package, with only Gitaly enabled |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | Network interfaces, EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `security-groups.tf` | Gitaly port from Praefect, SSH, metrics |
| `iam.tf` | Read the gitlab-shell token and Praefect's internal token |
| `scripts/user-data.sh.tftpl` | Writes `/etc/gitlab/gitlab.rb`, installs `gitlab-ce`, runs `gitlab-ctl reconfigure` |

There is no `secret-manager.tf`: the tokens Gitaly needs belong to the rails
and praefect modules.

## How it works

- **Fixed addresses:** network interfaces are created before the instances, so
  their IPs are known up front. The praefect module puts them in its
  `virtual_storage` configuration.
- **Clean install:** `gitlab.rb` and `/etc/gitlab/skip-auto-reconfigure` exist
  before the package is installed, so the package never starts a full
  all-in-one GitLab.
- **Git hooks** (on push) call GitLab's internal API at `https://<gitlab_domain>`
  through the rails NLB. With the self-signed certificate, the CA is installed
  into `/etc/gitlab/trusted-certs`.

## Ports

| Port | From | Purpose |
|---|---|---|
| 8075 | praefect | Gitaly gRPC |
| 9236 | monitoring | Gitaly metrics |
| 22, 9100 | VPN, monitoring | SSH, node_exporter |

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base`, `node_count`, `instance_type`, `volume_size` | Shared settings and size |
| `gitlab_version` | GitLab CE package version (empty = newest) |
| `gitlab_url`, `gitlab_ca_cert`, `gitlab_shell_secret_arn` | From the rails module |
| `praefect_internal_token_secret_arn`, `praefect_security_group_id` | From the praefect module |
| `monitoring_security_group_id` | Allowed to scrape metrics |

| Output | Used by |
|---|---|
| `storages` (name => IP) | praefect |
| `security_group_id`, `private_ips` | Root outputs |

## Check it

```bash
sudo gitlab-ctl status gitaly
sudo ls /var/opt/gitlab/git-data/repositories/@cluster   # repositories placed by Praefect
```
