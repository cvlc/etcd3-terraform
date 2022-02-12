resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = tls_private_key.ca.algorithm
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "etcd CA"
    organization = "Automated via Terraform"
    country      = "GB"
  }

  validity_period_hours = 43800 # 5 years
  is_ca_certificate     = true


  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
    "cert_signing"
  ]
}

resource "tls_private_key" "peer" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
  count       = var.cluster_size
}

resource "tls_cert_request" "peer" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.peer[count.index].private_key_pem
  dns_names       = ["peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}", "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"]
  count           = var.cluster_size

  subject {
    common_name  = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
    organization = "Automated via Terraform"
  }
}

resource "tls_locally_signed_cert" "peer" {
  cert_request_pem   = tls_cert_request.peer[count.index].cert_request_pem
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
  count              = var.cluster_size

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_private_key" "server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
  count       = var.cluster_size
}

resource "tls_cert_request" "server" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.server[count.index].private_key_pem
  dns_names       = ["peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}", "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"]
  count           = var.cluster_size

  subject {
    common_name  = "peer-${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"
    organization = "Automated via Terraform"
  }
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server[count.index].cert_request_pem
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
  count              = var.cluster_size

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_private_key" "client" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "client" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.client.private_key_pem
  dns_names       = ["${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns}"]

  subject {
    common_name  = "client"
    organization = "Automated via Terraform"
  }
}

resource "tls_locally_signed_cert" "client" {
  cert_request_pem   = tls_cert_request.client.cert_request_pem
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth"
  ]
}
