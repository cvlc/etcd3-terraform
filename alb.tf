resource "aws_lb" "internal" {
  name            = "${var.role}-internal-${var.environment}"
  security_groups = [aws_security_group.default.id]
  subnets         = data.aws_subnets.target.ids
  internal        = true
  idle_timeout    = 3600

  tags = {
    Name        = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
    environment = var.environment
    role        = var.role
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.id
  port              = 2379
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.http.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "http" {
  name     = "${var.role}-internal-${var.environment}-http"
  port     = 2379
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.target.id
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    path                = "/health"
    matcher             = "200,202"
    interval            = 10
  }
}

resource "aws_route53_record" "internal" {
  zone_id = aws_route53_zone.default.id
  name    = "${var.role}-alb.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
  type    = "A"

  alias {
    name                   = aws_lb.internal.dns_name
    zone_id                = aws_lb.internal.zone_id
    evaluate_target_health = false
  }
}
