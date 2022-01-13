provider "aws" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_subnets" "target" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.target.id]
  }

  tags = {
    (var.subnet_type) = "true"
  }
}

variable "vpc_id" {
  default     = "create"
  description = "The VPC ID to use or 'create' to create a new VPC"
}

variable "subnet_type" {
  default     = "Private"
  description = "The type of subnet to deploy to. This translates to a tag on the subnet with a value of true - eg. Private for Private: true or Public for Public: true"
}

variable "instance_type" {
  default     = "c5a.large"
  description = "AWS instance type, at least c5a.large is recommended. etcd suggest m4.large."
}

variable "environment" {
  default     = "development"
  description = "Target environment, used to apply tags"
}

variable "role" {
  default     = "ondat"
  description = "Role name used for internal logic"
}

variable "etcd_version" {
  default     = "3.5.1"
  description = "etcd version to install"
}

variable "ami" {
  default     = "ami-050949f5d3aede071"
  description = "AMI to launch with - suggest Debian"
}

variable "associate_public_ips" {
  default     = "false"
  description = "Whether to associate public IPs with etcd instances (suggest false for security)"
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

