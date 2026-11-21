# GitLab Runner

Six GitLab Runner machines with the Docker executor: every CI job runs in a
fresh container. All six register against one instance-wide runner, so any
project can use them.

Sizes are set directly in `compute.tf` (`count`, `instance_type`, `volume_size`, `concurrent`, `default_image`).

| | Value |
|---|---|
| Nodes | `runner-1..6`, two per AZ |
| Instance | `c8i.xlarge` (4 vCPU), 100 GiB gp3 for images and caches |
| Jobs at once | 4 per machine, 24 in total |
| Default image | `alpine:latest` |
| Tags | `docker`, `aws` (untagged jobs run too) |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `security-groups.tf` | SSH from the VPN, metrics |
| `iam.tf` | Read the runner token, nothing else |
| `scripts/user-data.sh.tftpl` | Installs Docker and gitlab-runner, waits for the token and for GitLab, registers |

## How it works

- **Token from rails-1.** rails-1 creates the instance runner after GitLab is
  up and stores its authentication token (`glrt-...`) in the `runner-token`
  secret. Each runner waits for that secret, then for `/-/readiness` to answer
  through the NLB, then runs `gitlab-runner register`.
- **Self-signed certificate:** the GitLab CA goes to
  `/etc/gitlab-runner/certs/<gitlab_domain>.crt`. The runner trusts it and
  hands it to jobs (`CI_SERVER_TLS_CA_FILE`), so `git clone` works inside job containers.
- **Jobs can't borrow AWS credentials.** The IAM role can only read the token,
  and the metadata service hop limit is 1, so containers can't reach it at all.
- Docker runs unprivileged. For Docker-in-Docker builds, set
  `privileged = true` in `/etc/gitlab-runner/config.toml`, and consider what
  that allows first.

## Ports

| Port | From | Purpose |
|---|---|---|
| 9252 | monitoring | Runner metrics |
| 22, 9100 | VPN, monitoring | SSH, node_exporter |

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base` | Shared settings (VPC, region, SSH key, VPN group) |
| `private_subnet_ids` | Exactly 3 private subnets; nodes go two per subnet/AZ |
| `gitlab_url`, `gitlab_ca_cert`, `runner_token_secret_arn` | From rails |
| `monitoring_security_group_id` | Allowed to scrape metrics |

| Output | Used by |
|---|---|
| `security_group_id`, `private_ips` | Root outputs |

## Check it

```bash
sudo gitlab-runner verify
sudo gitlab-runner list
```

In GitLab: **Admin → CI/CD → Runners** shows `aws-ec2-docker` with six managers.
