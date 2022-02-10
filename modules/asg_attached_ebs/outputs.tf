output "userdata_snippet" {
  description = "Snippet of userdata to assign to ASG instances"
  value       = join("\n", local.user_data_map)
}

output "iam_role_policy_arn" {
  description = "IAM role policy ARN to assign to ASG instance role"
  value       = aws_iam_policy.data.arn
}
