variable "ami_id" {}
variable "instance_type" { default = "t3.micro" }
variable "subnet_id" {}
variable "security_group_ids" { type = list(string) }
variable "key_name" {}
variable "eip_allocation" {
  description = "Elastic IP Allocation ID for associating with the instance"
  type        = string
  default     = null
}
variable "attach_eip" {
  type        = bool
  default     = false
  description = "Whether to attach the EIP"
}
variable "user_data" { default = "" }
variable "tags" { type = map(string) }
