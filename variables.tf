variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "my_domain" {
  description = "Hosted zone name"
  type        = string
  default     = "styrinov.com.ua"
}

variable "subdomain" {
  type        = string
  description = "ec2web"
  default     = "ec2web"
}

variable "lord_of_terraform" {
  description = "Owner of this project"
  type        = string
  default     = "Serhii Tyrinov"
}

variable "backup_bucket_name" {
  description = "The name of the S3 bucket used for EC2 backup storage"
  type        = string
  default     = "my-backup-bucket-0e407885-3158-4157-bfa3-a57a40f1b561"
}

variable "redis_user_name" {
  type        = string
  description = "Redis user name"
}

variable "redis_password" {
  type        = string
  description = "Redis user password"
  sensitive   = true
}

