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

variable "db_password" {
  description = "Password for RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "docker_compose_bucket_name" {
  description = "The name of the S3 bucket used for EC2 docker-compose storage"
  type        = string
}

variable "private_key_path" {
  description = "The path to private key"
  type        = string
}

variable "key_name" {
  description = "The key name of private key"
  type        = string
}

variable "ver" {
  type = object({
    env = string
  })
}

# Example:
# ver = { env = "dev" }

variable "postgres_user" {
  type        = string
  default     = "ghostfolio"
  description = "PostgreSQL username"
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL password"
  sensitive   = true
}

variable "postgres_db" {
  type    = string
  default = "ghostfolio"
}

variable "access_token_salt" {
  type      = string
  sensitive = true
}

variable "jwt_secret_key" {
  type      = string
  sensitive = true
}

variable "compose_project_name" {
  type    = string
  default = "ghostfolio"
}

variable "redis_user" {
  type    = string
  default = "ghostfolio"
}

variable "redis_password" {
  type      = string
  sensitive = true
}


