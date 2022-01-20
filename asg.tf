resource "aws_launch_configuration" "default" {
  count                       = var.cluster_size
  name_prefix                 = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}-"
  image_id                    = var.ami
  instance_type               = var.instance_type
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.default.id
  key_name                    = aws_key_pair.default.key_name
  enable_monitoring           = false
  associate_public_ip_address = var.associate_public_ips
  security_groups             = [aws_security_group.default.id]
  user_data = templatefile("${path.module}/cloudinit/userdata-template.sh", {
    environment  = var.environment,
    role         = var.role,
    region       = data.aws_region.current.name,
    etcd_version = var.etcd_version,
    etcd_url     = local.etcd_url,

    etcd_member_unit = templatefile("${path.module}/cloudinit/etcd_member_unit", {
      peer_name             = "peer-${count.index}"
      discovery_domain_name = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
      cluster_name          = var.role
    }),
    etcd_bootstrap_unit = templatefile("${path.module}/cloudinit/etcd_bootstrap_unit", {
      region                     = data.aws_region.current.name
      peer_name                  = "peer-${count.index}"
      discovery_domain_name      = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
      etcd3_bootstrap_binary_url = local.etcd3_bootstrap_binary_url
    }),
    ca_file                      = tls_self_signed_cert.ca.cert_pem,
    peer_cert_file               = tls_locally_signed_cert.peer[count.index].cert_pem,
    peer_key_file                = tls_private_key.peer[count.index].private_key_pem,
    server_cert_file             = tls_locally_signed_cert.server[count.index].cert_pem,
    server_key_file              = tls_private_key.server[count.index].private_key_pem,
    maintenance_day_of_the_month = count.index < 26 ? count.index + 1 : count.index - 25
  })
  root_block_device { encrypted = true }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [vpc_classic_link_security_groups, user_data]
  }
}

resource "aws_autoscaling_group" "default" {
  count                     = var.cluster_size
  name                      = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = element(aws_launch_configuration.default.*.name, count.index)
  vpc_zone_identifier       = [data.aws_subnet.target[count.index].id]
  target_group_arns         = [aws_lb_target_group.https.arn]
  wait_for_capacity_timeout = "0"
  tag {
    key                 = "Name"
    value               = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "role"
    value               = "peer-${count.index}.${var.role}"
    propagate_at_launch = true
  }

  tag {
    key                 = "cluster"
    value               = var.role
    propagate_at_launch = true
  }

  tag {
    key                 = "r53-domain-name"
    value               = "${var.environment}.${var.dns["domain_name"]}"
    propagate_at_launch = false
  }

  tag {
    key                 = "r53-zone-id"
    value               = aws_route53_zone.default.id
    propagate_at_launch = false
  }
  depends_on = [aws_ebs_volume.ssd, aws_lambda_permission.cloudwatch-dns-service-autoscaling]
}

data "aws_subnet" "target" {
  count  = var.cluster_size
  vpc_id = data.aws_vpc.target.id
  id     = element(data.aws_subnets.target.ids, count.index)
}

resource "aws_ebs_volume" "ssd" {
  count             = var.cluster_size
  snapshot_id       = lookup(var.restore_snapshot_ids, (count.index), "")
  availability_zone = data.aws_subnet.target[count.index].availability_zone
  size              = var.ssd_size
  encrypted         = true

  tags = {
    Name         = "peer-${count.index}-ssd.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
    environment  = var.environment
    role         = "peer-${count.index}-ssd.${var.role}"
    cluster      = var.role
    "snap-daily" = "true"
  }
}
