variable "name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "user_data" { default = "" }
variable "security_group_ids" {
  type = list(string)
}
variable "subnet_ids" {
  type = list(string)
}
variable "desired_capacity" {
  default = 1
}
variable "min_size" {
  default = 1
}
variable "max_size" {
  default = 3
}
variable "target_group_arns" {
  type    = list(string)
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
