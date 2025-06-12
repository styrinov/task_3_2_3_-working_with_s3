variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "my_domain" {
  description = "Hosted zone name"
  type        = string
  default     = "styrinov.com"
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