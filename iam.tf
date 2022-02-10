resource "aws_key_pair" "default" {
  key_name   = var.role
  public_key = var.key_pair_public_key
}

resource "aws_iam_role" "default" {
  name = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "default" {
  name       = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
  role       = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
  depends_on = [aws_iam_role.default]
}

