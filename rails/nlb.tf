# Frontend NLB, internal (reachable from the VPC and over the VPN only):
#   443 TLS (ACM certificate) -> Rails :80   HTTPS for users, runners, Gitaly hooks
#    22 TCP                   -> Rails :22   git clone git@gitlab...
# An ALB can't carry SSH, which is why this is an NLB.

resource "aws_security_group" "nlb" {
  name        = "gitlab-rails-nlb-${local.name_suffix}"
  description = "GitLab frontend NLB (HTTPS 443, Git SSH 22)"
  vpc_id      = var.base.vpc_id

  tags = {
    Name = "gitlab-rails-nlb-${local.name_suffix}"
  }
}

# Everyone inside the VPC: VPN users (NATed to the VPN's network interfaces),
# runners, Gitaly calling the internal API.
resource "aws_vpc_security_group_ingress_rule" "nlb" {
  for_each = { https = 443, ssh = 22 }

  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = var.base.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
  description       = each.key == "https" ? "GitLab HTTPS from the VPC" : "Git SSH from the VPC"
}

resource "aws_vpc_security_group_egress_rule" "nlb" {
  security_group_id = aws_security_group.nlb.id
  ip_protocol       = "-1"
  cidr_ipv4         = var.base.vpc_cidr
  description       = "To Rails nodes and health checks"
}

resource "aws_lb" "this" {
  name               = substr("gl-rails-${local.name_suffix}", 0, 32)
  internal           = true
  load_balancer_type = "network"
  subnets            = var.base.subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "gitlab-rails-${local.name_suffix}"
  }
}

resource "aws_lb_target_group" "http" {
  name               = substr("gl-http-${local.name_suffix}", 0, 32)
  port               = 80
  protocol           = "TCP"
  vpc_id             = var.base.vpc_id
  preserve_client_ip = "false"

  health_check {
    protocol            = "HTTP"
    port                = "80"
    path                = "/-/readiness"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "ssh" {
  name               = substr("gl-ssh-${local.name_suffix}", 0, 32)
  port               = 22
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

resource "aws_lb_target_group_attachment" "http" {
  for_each = aws_instance.this

  target_group_arn = aws_lb_target_group.http.arn
  target_id        = each.value.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ssh" {
  for_each = aws_instance.this

  target_group_arn = aws_lb_target_group.ssh.arn
  target_id        = each.value.id
  port             = 22
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "TLS"
  certificate_arn   = local.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "ssh" {
  load_balancer_arn = aws_lb.this.arn
  port              = 22
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ssh.arn
  }
}
