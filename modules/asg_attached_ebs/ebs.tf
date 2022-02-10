resource "aws_ebs_volume" "ssd" {
  for_each = { for key, value in var.attached_ebs : key => value }

  snapshot_id       = each.value.restore_snapshot
  availability_zone = var.availability_zone
  size              = each.value.disk_size
  iops              = each.value.iops
  type              = each.value.volume_type
  kms_key_id        = each.value.kms_key_id
  encrypted         = each.value.encrypted
  throughput        = each.value.throughput

  tags = merge({
    Name         = each.key
    "ebs-owner"  = var.asg_name
    "snap-daily" = "true"
  }, each.value.tags)
}
