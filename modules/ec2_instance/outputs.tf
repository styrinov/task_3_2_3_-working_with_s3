output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_eip_association.this[0].public_ip
}