# S3 buckets

- `private.tf`: general-purpose private bucket (logs, tmp).
- `gitlab.tf`: one private bucket per GitLab object type plus `backups` for the daily `gitlab-backup` archives.
