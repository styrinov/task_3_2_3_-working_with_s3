resource "aws_eip" "bastion_eip" {
  count = var.ver.env == "dev" ? 1 : 0

  instance = aws_instance.bastion[0].id
  domain   = "vpc"

  tags = {
    Name  = "bastion-eip"
    Owner = var.lord_of_terraform
  }
}

resource "aws_eip" "main" {
  domain = "vpc"

  tags = {
    Name  = "main-eip"
    Owner = var.lord_of_terraform
  }
}