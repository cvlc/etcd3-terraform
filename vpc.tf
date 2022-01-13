module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.2"
  name    = "etcd-test"
  cidr    = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway = true
  enable_vpn_gateway = true
  single_nat_gateway = true
  public_subnet_tags = {
    Public = "true"
  }
  private_subnet_tags = {
    Private = "true"
  }
  tags = {
    Terraform   = "true"
    Environment = "development"
  }

  count = var.vpc_id == "create" ? 1 : 0
}

data "aws_vpc" "target" {
  id = var.vpc_id == "create" ? module.vpc[0].vpc_id : var.vpc_id
}

