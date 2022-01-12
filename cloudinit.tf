data "template_file" "cloud-init" {
  count    = var.cluster_size
  template = file("${path.module}/cloudinit/userdata-template.sh")

  vars = {
    environment  = var.environment
    role         = var.role
    region       = data.aws_region.current.name
    etcd_version = var.etcd_version

    etcd_member_unit    = element(data.template_file.etcd_member_unit.*.rendered, count.index)
    etcd_bootstrap_unit = element(data.template_file.etcd_bootstrap_unit.*.rendered, count.index)
  }
}

data "template_file" "etcd_member_unit" {
  count    = var.cluster_size
  template = file("${path.module}/cloudinit/etcd_member_unit")

  vars = {
    peer_name             = "peer-${count.index}"
    discovery_domain_name = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
    cluster_name          = var.role
  }
}

data "template_file" "etcd_bootstrap_unit" {
  count    = var.cluster_size
  template = file("${path.module}/cloudinit/etcd_bootstrap_unit")

  vars = {
    region                     = data.aws_region.current.name
    peer_name                  = "peer-${count.index}"
    discovery_domain_name      = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
    etcd3_bootstrap_binary_url = "https://${aws_s3_bucket.files.bucket_domain_name}/etcd3-bootstrap-linux-amd64"
  }
}

