data "template_file" "cloud-init" {
  count    = var.cluster_size
  template = file("${path.module}/cloudinit/userdata-template.sh")

  vars = {
    environment  = var.environment
    role         = var.role
    region       = data.aws_region.current.name
    etcd_version = var.etcd_version
    etcd_url     = local.etcd_url

    etcd_member_unit             = element(data.template_file.etcd_member_unit.*.rendered, count.index)
    etcd_bootstrap_unit          = element(data.template_file.etcd_bootstrap_unit.*.rendered, count.index)
    ca_file                      = tls_self_signed_cert.ca.cert_pem
    peer_cert_file               = tls_locally_signed_cert.peer[count.index].cert_pem
    peer_key_file                = tls_private_key.peer[count.index].private_key_pem
    server_cert_file             = tls_locally_signed_cert.server[count.index].cert_pem
    server_key_file              = tls_private_key.server[count.index].private_key_pem
    maintenance_day_of_the_month = ceil((count.index + 1) * (27 / var.cluster_size))
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
    etcd3_bootstrap_binary_url = local.etcd3_bootstrap_binary_url
  }
}

