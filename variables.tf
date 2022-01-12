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
    "Public" = "true"
  }
}

variable "vpc_id" {
  default = "create"
  description = "The VPC ID to use or 'create' to create a new VPC"
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
  default     = "true"
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

variable "ntp_host" {
  default     = "0.europe.pool.ntp.org"
  description = "NTP host to use for time coordination"
}
