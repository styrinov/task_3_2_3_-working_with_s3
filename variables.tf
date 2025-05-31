variable "bucket_name" {
  description = "Unique S3 bucket name"
  type        = string
  default     = "95145adf-8ef7-4823-8351-e4ed2abcec3e-working-with-s3"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}
