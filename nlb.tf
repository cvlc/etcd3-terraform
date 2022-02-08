resource "aws_lb" "nlb" {
  name               = "${var.role}-${var.environment}"
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  internal           = var.nlb_internal

  tags = {
    Name        = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
    environment = var.environment
    role        = var.role
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.nlb.id
  port              = 2379
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.https.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "https" {
  name     = "${var.role}-${var.environment}-https"
  port     = 2379
  protocol = "TCP"
  vpc_id   = data.aws_vpc.target.id
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    port                = 8080
    path                = "/health"
    protocol            = "HTTP"
    interval            = 10
  }
}

resource "aws_route53_record" "nlb" {
  zone_id = aws_route53_zone.default.id
  name    = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
  type    = "A"

  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = false
  }
}
