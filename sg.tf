resource "aws_security_group" "default" {
  name        = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
  description = "ASG-${var.role}"
  vpc_id      = data.aws_vpc.target.id

  tags = {
    Name        = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
    role        = var.role
    environment = var.environment
  }
}
resource "aws_security_group_rule" "etcd_peers_i" {
  # etcd peer + client traffic within the etcd nodes themselves
  type              = "ingress"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_peers_e" {
  # etcd peer + client traffic within the etcd nodes themselves
  type              = "egress"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_clients_i" {
  # etcd peer + client traffic within the etcd nodes themselves
  type              = "ingress"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  cidr_blocks       = var.client_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_health_i" {
  # plain http healthcheck and metrics from lb & to/from peers
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = var.client_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_health_e" {
  # plain http healthcheck and metrics from lb & to/from peers
  type              = "egress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = var.client_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_heal_p_e" {
  # plain http healthcheck and metrics from lb & to/from peers
  type              = "egress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.target.cidr_block]
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_heal_p_i" {
  # plain http healthcheck and metrics from lb & to/from peers
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.target.cidr_block]
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_heal_a_i" {
  # plain http healthcheck and metrics from lb & to/from peers
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "etcd_heal_a_e" {
  # plain http healthcheck and metrics from lb & to/from peers
  type              = "egress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "ssh_i" {
  count = length(var.ssh_cidrs) > 0 ? 1 : 0
  # ssh
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "tls_e" {
  count = length(var.allow_download_from_cidrs) > 0 ? 1 : 0
  # https outbound (for github and metadata access)
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allow_download_from_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "ntp_t_e" {
  count = length(var.allow_download_from_cidrs) > 0 ? 1 : 0
  # ntp outbound (TCP)
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "tcp"
  cidr_blocks       = var.allow_download_from_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "ntp_u_e" {
  count = length(var.allow_download_from_cidrs) > 0 ? 1 : 0
  # ntp outbound (UDP)
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks       = var.allow_download_from_cidrs
  security_group_id = aws_security_group.default.id
}
