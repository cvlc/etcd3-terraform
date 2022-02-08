data "aws_ami" "ami" {
  most_recent = true
  name_regex  = var.ami_name_regex

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_owner] # Canonical
}
