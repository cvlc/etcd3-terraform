terraform {
  experiments = [module_variable_optional_attrs]
}

variable "availability_zone" {
  type        = string
  description = "The availability zone to create the EBS volume in"
}

variable "asg_name" {
  type        = string
  description = "Name of the ASG for the EBSes to be attached to"
}

variable "attached_ebs" {
  type        = any
  description = "Map of the EBS objects to allocate"
}

variable "ebs_bootstrap_binary_url" {
  default     = null
  description = "Custom URL from which to download the ebs_bootstrap binary"
}
