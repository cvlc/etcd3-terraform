resource "aws_s3_bucket" "files" {
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
  bucket = aws_s3_bucket.files.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_object" "etcd3-bootstrap-linux-amd64" {
  bucket       = aws_s3_bucket.files.id
  key          = "etcd3-bootstrap-linux-amd64"
  source       = "files/etcd3-bootstrap-linux-amd64"
  etag         = filemd5("files/etcd3-bootstrap-linux-amd64")
  acl          = "public-read"
  content_type = "application/octet-stream"
}
