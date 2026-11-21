# Gossip encryption key, shared by the servers and every agent (PostgreSQL
# nodes). Agents' modules get read access through the gossip_secret_arn output.

resource "random_id" "gossip_key" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "gossip_key" {
  name        = "gitlab/${local.name_suffix}/consul/gossip-key"
  description = "Consul gossip encryption key"

  # Deleted immediately on destroy so a rebuilt environment can reuse the name.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gossip_key" {
  secret_id     = aws_secretsmanager_secret.gossip_key.id
  secret_string = random_id.gossip_key.b64_std
}
