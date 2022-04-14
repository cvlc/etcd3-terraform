resource "aws_launch_configuration" "default" {
  count                       = var.cluster_size
  name_prefix                 = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}-"
  image_id                    = var.ami != "" ? var.ami : data.aws_ami.ami.id
  instance_type               = var.instance_type
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.default[count.index].id
  key_name                    = var.key_pair_public_key == "" ? null : aws_key_pair.default[0].key_name
  enable_monitoring           = false
  associate_public_ip_address = var.associate_public_ips
  security_groups             = [aws_security_group.default.id]
  user_data = join("\n", ["#!/bin/bash", module.attached-ebs.userdata_snippets_by_az[data.aws_subnet.target[count.index].availability_zone], templatefile("${path.module}/cloudinit/userdata-template.sh", {
    environment  = var.environment,
    role         = var.role,
    region       = data.aws_region.current.name,
    etcd_version = var.etcd_version,
    etcd_url     = local.etcd_url,

    etcd_member_unit = templatefile("${path.module}/cloudinit/etcd_member_unit", {
      peer_name             = "peer-${count.index}"
      discovery_domain_name = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
      cluster_name          = var.role
    }),
    etcd_endpoint                = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
    ca_file                      = tls_self_signed_cert.ca.cert_pem,
    peer_cert_file               = tls_locally_signed_cert.peer[count.index].cert_pem,
    peer_key_file                = tls_private_key.peer[count.index].private_key_pem,
    server_cert_file             = tls_locally_signed_cert.server[count.index].cert_pem,
    server_key_file              = tls_private_key.server[count.index].private_key_pem,
    maintenance_day_of_the_month = count.index < 26 ? count.index + 1 : count.index - 25
  })])
  root_block_device { encrypted = true }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [vpc_classic_link_security_groups]
  }
}

resource "aws_autoscaling_group" "default" {
  count                     = var.cluster_size
  name                      = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
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
    value               = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Group"
    value               = "peer.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
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
    value               = "${var.environment}.${var.dns}"
    propagate_at_launch = false
  }

  tag {
    key                 = "r53-zone-id"
    value               = aws_route53_zone.default.id
    propagate_at_launch = false
  }
  depends_on = [aws_lambda_permission.cloudwatch-dns-service-autoscaling]
}

data "aws_subnet" "target" {
  count  = var.cluster_size
  vpc_id = data.aws_vpc.target.id
  id     = element(var.subnet_ids, count.index)
}

module "attached-ebs" {
  source                   = "github.com/ondat/etcd3-bootstrap//terraform/modules/attached_ebs"
  group                    = "peer.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
  ebs_bootstrap_binary_url = var.ebs_bootstrap_binary_url
  attached_ebs = {
    for i in range(var.cluster_size) :
    "data-${i}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}" => {
      size                    = var.ssd_size
      availability_zone       = element(data.aws_subnet.target, i)["availability_zone"]
      encrypted               = true
      volume_type             = "gp3"
      block_device_aws        = "/dev/xvdf"
      block_device_os         = "/dev/nvme1n1"
      block_device_mount_path = "/var/lib/etcd"
      tags = {
        environment = var.environment
        role        = "peer-${i}-ssd.${var.role}"
        cluster     = var.role
      }
    }
  }
}
