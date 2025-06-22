variable "name" {}
variable "owner" {}
variable "vpc_id" {}
variable "subnet_ids" {
  type = list(string)
}
variable "allowed_sg_id" {}
variable "redis_user_name" {}
variable "redis_password" {}
