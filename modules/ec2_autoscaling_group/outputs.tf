output "asg_name" {
  value = aws_autoscaling_group.this.name
}
output "lt_id" {
  value = aws_launch_template.this.id
}
