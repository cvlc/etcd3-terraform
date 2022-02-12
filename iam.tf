resource "aws_key_pair" "default" {
  key_name   = var.role
  public_key = var.key_pair_public_key
}

resource "aws_iam_policy" "default" {
  name        = "${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
  path        = "/"
  description = "Allow data volume management for instances"
  policy      = module.attached-ebs.iam_role_policy_document
}

resource "aws_iam_role" "default" {
  name  = "${count.index}.${var.role}.${data.aws_region.current.name}.i.${var.environment}.${var.dns["domain_name"]}"
  count = var.cluster_size

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
  count = var.cluster_size
  name  = aws_iam_role.default[count.index].name
  role  = aws_iam_role.default[count.index].name
}

resource "aws_iam_role_policy_attachment" "default" {
  count      = var.cluster_size
  role       = aws_iam_role.default[count.index].name
  policy_arn = aws_iam_policy.default.arn
}
