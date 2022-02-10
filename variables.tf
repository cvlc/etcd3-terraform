data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_vpc" "target" {
  id = var.vpc_id
}

variable "vpc_id" {
  description = "The VPC ID to use"
}

variable "subnet_ids" {
  description = "The subnet IDs to which to deploy etcd"
}

variable "nlb_internal" {
  default     = true
  description = "'true' to expose the NLB internally only, 'false' to expose it to the internet"
}
variable "instance_type" {
  default     = "c5a.large"
  description = "AWS instance type, at least c5a.large is recommended. etcd suggest m4.large."
}

variable "ssd_size" {
  default     = "100"
  description = "Size (in GB) of the SSD to be used for etcd data storage"
}

variable "restore_snapshot_ids" {
  type        = map(string)
  default     = {}
  description = "Map of of the snapshots to use to restore etcd data storage - eg. {0: \"snap-abcdef\", 1: \"snap-fedcba\", 2: \"snap-012345\"}"
}

variable "environment" {
  default     = "development"
  description = "Target environment, used to apply tags"
}

variable "role" {
  default     = "etcd"
  description = "Role name used for internal logic"
}

variable "etcd_version" {
  default     = "3.5.1"
  description = "etcd version to install"
}

variable "etcd_url" {
  default     = null
  description = "Custom URL from which to download the etcd tgz"
}

variable "etcd3_bootstrap_binary_url" {
  default     = null
  description = "Custom URL from which to download the etcd3-bootstrap binary"
}

locals {
  etcd_url_github            = "https://github.com/etcd-io/etcd/releases/download/v${var.etcd_version}/etcd-v${var.etcd_version}-linux-amd64.tar.gz"
  etcd_url                   = var.etcd_url == null ? local.etcd_url_github : var.etcd_url
}

variable "ami" {
  default     = ""
  description = "AMI to launch with - if set, overrides the value found via ami_name_regex and ami_owner"
}

variable "ami_name_regex" {
  default     = "ubuntu/images/hvm-ssd/ubuntu-.*-amd64-server-*"
  description = "Regex to match the preferred AMI name"
}

variable "ami_owner" {
  default     = "099720109477" # Canonical
  description = "AMI owner ID"
}

variable "associate_public_ips" {
  default     = "false"
  description = "Whether to associate public IPs with etcd instances (suggest false for security)"
}

variable "allow_download_from_cidrs" {
  default     = ["0.0.0.0/0"]
  description = "CIDRs from which to allow downloading etcd and etcd-bootstrap binaries via TLS (443 outbound). By default, this is totally open as S3 and GitHub IP addresses are unpredictable."
}

variable "dns" {
  type = map(string)

  default = {
    domain_name = "mycompany.local"
  }

  description = "Domain to install etcd"
}

variable "key_pair_public_key" {
  description = "Public key for SSH access"
}

variable "cluster_size" {
  default     = 3
  description = "Number of etcd nodes to launch"
}

variable "client_cidrs" {
  default     = ["10.0.0.0/8"]
  description = "CIDRs to allow client access to etcd"
}

variable "ssh_cidrs" {
  default     = []
  description = "CIDRs to allow SSH access to the nodes from (by default, none)"
}
output "ca_cert" {
  value       = tls_self_signed_cert.ca.cert_pem
  description = "CA certificate to add to client trust stores (also see ./ca.pem)"
}

output "client_cert" {
  value       = tls_locally_signed_cert.client.cert_pem
  description = "Client certificate to use to authenticate with etcd (also see ./client.pem)"
}

output "client_key" {
  value       = tls_private_key.client.private_key_pem
  description = "Client private key to use to authenticate with etcd (also see ./client.key)"
  sensitive   = true
}

output "lb_address" {
  value       = aws_route53_record.nlb.name
  description = "Load balancer address for use by clients"
}
