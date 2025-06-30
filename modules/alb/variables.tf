variable "name" {
  description = "Name prefix for ALB and target group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ALB and target group"
  type        = string
}

variable "subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group ID to attach to the ALB"
  type        = string
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS"
  type        = string
}

variable "target_group_port" {
  description = "Port for target group"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
