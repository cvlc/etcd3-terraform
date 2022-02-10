# asg_attached_ebs
## Introduction
asg_attached_ebs is a Terraform module used to generate persistent EBS volumes and attach them to auto-scaled instances, ensuring that snapshots are taken of them daily.

## Usage
Set the input variable `asg_name` to the name of the auto-scaling group to attach the EBS to. This must be size `1` in order to prevent contention over the EBS volumes.

The input variable `attached_ebs` takes a map of volume definitions to attach to instances on boot:
```
attached_ebs = { 
  "ondat_data_1": {
    size = 100
    encrypted = true
    volume_type = gp3
    block_device_aws = "/dev/xvda1"
    block_device_os = "/dev/nvme0n1"
    block_device_mount_path = "/var/lib/data0"
  }
  "ondat_data_1": {
    size = 100
    encrypted = true
    restore_snapshot = ""
    iops = 3000
    volume_type = io2
    throughput = 150000
    kms_key_id = "arn:aws::kms/..."
    block_device_aws = /dev/xvda2
    block_device_os = /dev/nvme1n1
    block_device_mount_path = /var/lib/data1
  }
}
```

For airgapped or private environments, the variable `ebs_bootstrap_binary_url` can be used to provide an HTTP/S address from which to retrieve the necessary binary.

Use the output `iam_role_policy_arn` to assign the policy to your ASG node's role.
Use the output `userdata_snippet` to embed in your ASG's userdata. 

## Appendix

### Requirements

No requirements.

### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_dlm_lifecycle_policy.automatic_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dlm_lifecycle_policy) | resource |
| [aws_ebs_volume.ssd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_iam_policy.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.dlm_lifecycle_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.dlm_lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_policy_document.ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_asg_name"></a> [asg\_name](#input\_asg\_name) | Name of the ASG for the EBSes to be attached to | `string` | n/a | yes |
| <a name="input_attached_ebs"></a> [attached\_ebs](#input\_attached\_ebs) | Map of the EBS objects to allocate | `any` | n/a | yes |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | The availability zone to create the EBS volume in | `string` | n/a | yes |
| <a name="input_ebs_bootstrap_binary_url"></a> [ebs\_bootstrap\_binary\_url](#input\_ebs\_bootstrap\_binary\_url) | Custom URL from which to download the ebs\_bootstrap binary | `any` | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam_role_policy_arn"></a> [iam\_role\_policy\_arn](#output\_iam\_role\_policy\_arn) | IAM role policy ARN to assign to ASG instance role |
| <a name="output_userdata_snippet"></a> [userdata\_snippet](#output\_userdata\_snippet) | Snippet of userdata to assign to ASG instances |
