# Internal NLB on 2305 in front of the Praefect nodes. Rails and Sidekiq use it
# as their single Gitaly address.

resource "aws_security_group" "nlb" {
  name        = "gitlab-praefect-nlb-${local.name_suffix}"
  description = "GitLab Praefect NLB"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-praefect-nlb-${local.name_suffix}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb" {
  for_each = var.client_security_group_ids

  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 2305
  to_port                      = 2305
  description                  = "Praefect from ${each.key}"
}

resource "aws_vpc_security_group_egress_rule" "nlb" {
  security_group_id = aws_security_group.nlb.id
  ip_protocol       = "-1"
  cidr_ipv4         = var.base.vpc_cidr
  description       = "To Praefect nodes and health checks"
}

resource "aws_lb" "this" {
  name               = substr("gl-praefect-${local.name_suffix}", 0, 32)
  internal           = true
  load_balancer_type = "network"
  subnets            = var.base.subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "gitlab-praefect-${local.name_suffix}"
  }
}

resource "aws_lb_target_group" "this" {
  name               = substr("gl-praefect-${local.name_suffix}", 0, 32)
  port               = 2305
  protocol           = "TCP"
  vpc_id             = var.base.vpc_id
  preserve_client_ip = "false"

  health_check {
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = aws_instance.this

  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.value.id
  port             = 2305
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 2305
  protocol          = "TCP"
  # Long-lived gRPC connections; the 350 s default would drop idle ones.
  tcp_idle_timeout_seconds = 3600

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
