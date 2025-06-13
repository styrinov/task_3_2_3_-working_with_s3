output "data_aws_availability_zones" {
  value = data.aws_availability_zones.availability_zones.names
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "data_aws_region_name" {
  value = data.aws_region.current.name
}

output "data_aws_region_description" {
  value = data.aws_region.current.description
}

output "data_aws_vpcs_my_vpcs" {
  value = data.aws_vpcs.my_vpcs.ids
}

output "data_aws_route53_zone_id" {
  value = data.aws_route53_zone.styrinov.zone_id
}

output "latest_ubuntu_ami_id" {
  value = data.aws_ami.latest_ubuntu.id
}

output "latest_ubuntu_ami_name" {
  value = data.aws_ami.latest_ubuntu.name
}

output "eip_public_ip" {
  value = aws_eip.main.public_ip
}

output "ec2_public_ip" {
  value = module.web_instance.public_ip
}
