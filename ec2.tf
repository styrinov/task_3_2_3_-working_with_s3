# -------------------- EC2 Instance --------------------
module "web_instance" {
  source               = "./modules/ec2_instance"
  ami_id               = data.aws_ami.latest_ubuntu.id
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.public_subnets[0]
  key_name             = var.key_name
  security_group_ids   = [aws_security_group.web_sg.id]
  eip_allocation       = aws_eip.main.id
  attach_eip           = true
  user_data            = file("${path.module}/user_data.sh")
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

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
      private_key = file(var.private_key_path)
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
      private_key = file(var.private_key_path)
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
      private_key = file(var.private_key_path)
    }
  }

  # Step 4: Upload rendered .env file content
  provisioner "file" {
    content     = local.envfile_content
    destination = "/home/ubuntu/projects/.env"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = module.web_instance.public_ip
      private_key = file(var.private_key_path)
    }
  }

  # Step 5: Wait for cloud-init, then run deploy script
  provisioner "remote-exec" {
    inline = [
      # Wait for cloud-init (user_data) to finish
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 5; done",

      # Then run the deploy script
      "sudo /home/ubuntu/projects/deploy.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = module.web_instance.public_ip
      private_key = file(var.private_key_path)
    }
  }

}

resource "aws_instance" "bastion" {
  count         = var.ver.env == "dev" ? 1 : 0
  ami           = data.aws_ami.latest_ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.bastion_sg[0].id]

  associate_public_ip_address = true

  user_data = file("${path.module}/bastion_user_data.sh")

  tags = {
    Name  = "bastion-dev"
    Owner = var.lord_of_terraform
  }
}

locals {
  envfile_content = templatefile("${path.module}/conf/envfile.tpl", {
    postgres_host        = module.postgres_rds.endpoint
    POSTGRES_USER        = var.postgres_user
    POSTGRES_PASSWORD    = var.postgres_password
    POSTGRES_DB          = var.postgres_db
    ACCESS_TOKEN_SALT    = var.access_token_salt
    JWT_SECRET_KEY       = var.jwt_secret_key
    COMPOSE_PROJECT_NAME = var.compose_project_name
    REDIS_USER           = var.redis_user
    REDIS_PASSWORD       = var.redis_password
  })
}

resource "local_file" "rendered_env" {
  filename = "${path.module}/.env"
  content  = local.envfile_content
}


resource "null_resource" "upload_env_to_s3" {
  depends_on = [local_file.rendered_env]

  provisioner "local-exec" {
    command = "aws s3 cp ${local_file.rendered_env.filename} s3://${var.docker_compose_bucket_name}/.env"
  }
}

