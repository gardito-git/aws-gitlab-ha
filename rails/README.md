# GitLab Rails

Three GitLab Rails nodes (NGINX, Workhorse and Puma) behind the frontend NLB,
serving the web UI, the API, and Git over HTTPS and SSH. This module also owns
GitLab's front door: the NLB, the private DNS name and the TLS certificate.

Sizes are set directly in `compute.tf` (`count`, `instance_type`, `volume_size`, and the backup schedule `backup_cron`).

| | Value |
|---|---|
| Nodes | `rails-1..3`, one per AZ |
| Instance | `c8i.xlarge` (4 vCPU, 8 GiB), 100 GiB gp3 |
| URL | `https://gitlab.example.com`, inside the VPC / over the VPN only |
| Software | GitLab CE package |
| Installed by | [scripts/user-data.sh.tftpl](scripts/user-data.sh.tftpl) at first boot |

## Files

| File | What's in it |
|---|---|
| `compute.tf` | EC2 nodes, key pair, Ubuntu 24.04 AMI |
| `nlb.tf` | Internal NLB: 443 TLS → :80, 22 TCP → :22; health check `/-/readiness` |
| `dns-tls.tf` | Private Route 53 zone for `gitlab_domain`; ACM certificate (public or self-signed) |
| `security-groups.tf` | HTTP and SSH from the NLB, SSH from the VPN, metrics |
| `iam.tf` | S3 object storage and backups; read secrets; write the two secrets rails-1 fills in |
| `secret-manager.tf` | root password, gitlab-shell token, SSH host key, `gitlab-secrets-json`, `runner-token` |
| `scripts/user-data.sh.tftpl` | Writes `gitlab.rb`, installs `gitlab-ce`, joins the cluster; extra one-off setup on rails-1 |

## How it works

**TLS and DNS**
- The NLB ends TLS with an ACM certificate and forwards plain HTTP to NGINX on port 80.
- `gitlab_domain` lives in a **private** hosted zone, so it resolves only inside
  the VPC, which includes VPN clients.
- **Certificate:**
  - With `route53_public_zone_id` set, ACM issues a real certificate.
  - Without it, Terraform creates a CA, imports a self-signed certificate, and
    hands the CA to Gitaly, Sidekiq and the runners.

**rails-1 is special.** It is the only node that:
1. runs the database migrations (`auto_migrate = true`);
2. generates `/etc/gitlab/gitlab-secrets.json` (the encryption keys every
   Rails and Sidekiq node must share) and uploads it to the `gitlab-secrets-json` secret;
3. turns off `authorized_keys` writes, creates the instance runner and stores
   its token in the `runner-token` secret;
4. installs the backup cron job (`/etc/cron.d/gitlab-backup`, daily at 00:00 UTC).

rails-2/3 (and Sidekiq) wait until `gitlab-secrets-json` has a value, then
download it before their first reconfigure. If rails-1 is ever rebuilt, it
downloads the existing file instead of generating a new one.

**Git over SSH through the NLB.**
- All three nodes use the same SSH host key, from the `ssh-host-key` secret.
- sshd looks up users' keys in GitLab's database (`AuthorizedKeysCommand`) instead of a per-node file.

**Object storage.**
- One private S3 bucket per object type, accessed with the instance role
  (`use_iam_profile`).
- `proxy_download = true`, so clients only ever talk to GitLab.

## Secrets

| Secret | Value comes from | Read by |
|---|---|---|
| `.../rails/root-password` | Terraform | rails |
| `.../rails/gitlab-shell-token` | Terraform | rails, sidekiq, gitaly |
| `.../rails/ssh-host-key` | Terraform | rails |
| `.../rails/gitlab-secrets-json` | **rails-1 at first boot** | rails, sidekiq. **Needed to restore a backup** |
| `.../rails/runner-token` | **rails-1 at first boot** | runner |

## Ports

| Port | From | Purpose |
|---|---|---|
| 80 | NLB, monitoring | GitLab HTTP, `/-/metrics` |
| 22 | NLB, VPN | Git over SSH, admin SSH |
| 9229, 8083, 9168 | monitoring | Workhorse, Puma, gitlab-exporter metrics |
| 9100 | monitoring | node_exporter |

The NLB accepts 443 and 22 from the whole VPC (VPN users, runners, Gitaly hooks).

## Inputs and outputs

| Input | Meaning |
|---|---|
| `base` | Shared settings (VPC, region, SSH key, VPN group) |
| `private_subnet_ids` | Exactly 3 private subnets; nodes go one per subnet/AZ |
| `gitlab_version`, `gitlab_domain`, `route53_public_zone_id` | GitLab settings |
| `postgres_endpoint`, `gitlab_db_secret_arn` | From postgres |
| `redis_sentinel_hosts`, `redis_master_name`, `redis_password_secret_arn` | From redis |
| `praefect_endpoint`, `praefect_external_token_secret_arn` | From praefect |
| `object_buckets`, `backup_bucket`, `bucket_arns` | From s3 |
| `prometheus_address`, `monitoring_security_group_id` | From monitoring |

| Output | Used by |
|---|---|
| `gitlab_url`, `gitlab_ca_cert` | gitaly, sidekiq, runner |
| `gitlab_shell_secret_arn` | gitaly, sidekiq |
| `gitlab_secrets_json_secret_arn` | sidekiq |
| `runner_token_secret_arn` | runner |
| `root_password_secret_arn`, `git_ssh_host_key` | Root outputs, for you |

## Check it

```bash
sudo gitlab-rake gitlab:check SANITIZE=true
sudo gitlab-rake gitlab:gitaly:check
curl -s http://127.0.0.1/-/readiness?all=1 | jq
sudo ls /etc/cron.d/gitlab-backup && sudo gitlab-backup create   # manual backup (rails-1)
```
