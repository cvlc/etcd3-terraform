resource "aws_iam_policy" "data" {
  name        = "${var.asg_name}-data-policy"
  path        = "/"
  description = "Allow data volume management for ASG nodes from ${var.asg_name}"
  policy      = data.aws_iam_policy_document.ebs.json
}
