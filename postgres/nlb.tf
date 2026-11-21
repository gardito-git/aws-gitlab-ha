# Internal NLB on 5432 that always points at the current primary. It forwards
# to PostgreSQL but decides health on Patroni's REST API: only the leader
# answers 200 on GET :8008/primary. This replaces PgBouncer + HAProxy.

resource "aws_security_group" "nlb" {
  name        = "gitlab-postgres-nlb-${local.name_suffix}"
  description = "GitLab PostgreSQL NLB"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-postgres-nlb-${local.name_suffix}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb" {
  for_each = var.client_security_group_ids

  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from ${each.key}"
}

resource "aws_vpc_security_group_egress_rule" "nlb" {
  security_group_id = aws_security_group.nlb.id
  ip_protocol       = "-1"
  cidr_ipv4         = var.base.vpc_cidr
  description       = "To PostgreSQL nodes and health checks"
}

resource "aws_lb" "this" {
  name               = substr("gl-pg-${local.name_suffix}", 0, 32)
  internal           = true
  load_balancer_type = "network"
  subnets            = var.base.subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  # Required: the single healthy primary lives in one AZ, and every NLB node
  # must be able to reach it.
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "gitlab-postgres-${local.name_suffix}"
  }
}

resource "aws_lb_target_group" "this" {
  name               = substr("gl-pg-${local.name_suffix}", 0, 32)
  port               = 5432
  protocol           = "TCP"
  vpc_id             = var.base.vpc_id
  preserve_client_ip = "false"

  health_check {
    protocol            = "HTTP"
    port                = "8008"
    path                = "/primary"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # When the old primary turns unhealthy its connections are cut, so clients
  # reconnect to the new one.
  target_health_state {
    enable_unhealthy_connection_termination = true
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = aws_instance.this

  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.value.id
  port             = 5432
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 5432
  protocol          = "TCP"
  # Rails keeps idle connections in its pool; the 350 s default would drop them.
  tcp_idle_timeout_seconds = 3600

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
