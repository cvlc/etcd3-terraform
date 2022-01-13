resource "aws_s3_bucket" "files" {
  count         = var.create_s3_bucket == "true" ? 1 : 0
  bucket_prefix = "etcd3-files"
  acl           = "private"
  versioning {
    enabled = true
  }
  tags = {
    environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  count  = var.create_s3_bucket == "true" ? 1 : 0
  bucket = aws_s3_bucket.files[count.index].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_object" "etcd3-bootstrap-linux-amd64" {
  count        = var.create_s3_bucket == "true" ? 1 : 0
  bucket       = aws_s3_bucket.files[count.index].id
  key          = "etcd3-bootstrap-linux-amd64"
  source       = "files/etcd3-bootstrap-linux-amd64"
  source_hash  = filemd5("files/etcd3-bootstrap-linux-amd64")
  acl          = "public-read"
  content_type = "application/octet-stream"
}
