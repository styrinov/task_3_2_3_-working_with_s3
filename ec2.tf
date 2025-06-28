# -------------------- EC2 Instance --------------------
module "web_instance" {
  source             = "./modules/ec2_instance"
  ami_id             = data.aws_ami.latest_ubuntu.id
  instance_type      = "t3.micro"
  subnet_id          = module.vpc.public_subnets[0]
  key_name           = "sergey-key-stockholm"
  security_group_ids = [aws_security_group.web_sg.id]
  eip_allocation     = aws_eip.main.id
  attach_eip         = true
  user_data          = file("${path.module}/user_data.sh")

  tags = {
    Name  = "Web Server Build by Terraform"
    Owner = var.lord_of_terraform
  }
}

resource "null_resource" "prepare_deploy_script" {
  depends_on = [module.web_instance]

  # Step 1: Ensure /home/ubuntu/projects exists
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/projects"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = module.web_instance.public_ip
      private_key = file("ec2_key.pem")
    }
  }

  # Step 2: Upload deploy.sh
  provisioner "file" {
    source      = "${path.module}/deploy.sh"
    destination = "/home/ubuntu/projects/deploy.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = module.web_instance.public_ip
      private_key = file("ec2_key.pem")
    }
  }

  # Step 3: Make script executable
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/projects/deploy.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = module.web_instance.public_ip
      private_key = file("ec2_key.pem")
    }
  }
}

resource "aws_instance" "bastion" {
  count         = var.ver.env == "dev" ? 1 : 0
  ami           = data.aws_ami.latest_ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = "sergey-key-stockholm"

  vpc_security_group_ids = [aws_security_group.bastion_sg[0].id]

  associate_public_ip_address = true

  user_data = file("${path.module}/bastion_user_data.sh")

  tags = {
    Name  = "bastion-dev"
    Owner = var.lord_of_terraform
  }
}

resource "aws_eip" "bastion_eip" {
  count = var.ver.env == "dev" ? 1 : 0

  instance = aws_instance.bastion[0].id
  domain   = "vpc"

  tags = {
    Name  = "bastion-eip"
    Owner = var.lord_of_terraform
  }
}