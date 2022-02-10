locals {
  user_data_map = [for key, value in var.attached_ebs : {
    key = templatefile("${path.module}/cloudinit/userdata-template.sh", {
      region          = data.aws_region.current.name,
      ebs_volume_name = key,
      ebs_bootstrap_unit = templatefile("${path.module}/cloudinit/ebs_bootstrap_unit", {
        region                   = data.aws_region.current.name
        ebs_volume_name          = key
        ebs_block_device_aws     = value.block_device_aws
        ebs_block_device_os      = value.block_device_os
        ebs_mount_point          = value.mount_point
        ebs_bootstrap_binary_url = local.ebs_bootstrap_binary_url
      }),
    }) }
  ]
  ebs_bootstrap_binary  = "https://github.com/ondat/etcd3-bootstrap/releases/download/v0.0.1/etcd3-bootstrap-linux-amd64"
  ebs_bootstrap_binary_url = var.ebs_bootstrap_binary_url == null ? local.ebs_bootstrap_binary : var.ebs_bootstrap_binary_url

}
