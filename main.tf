resource "aws_eip" "main" {
  domain = "vpc"

  tags = {
    Name  = "main-eip"
    Owner = var.lord_of_terraform
  }
}


resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.styrinov.zone_id
  name    = "${var.subdomain}.${var.my_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.main.public_ip]
}


resource "aws_security_group" "web_sg" {
  name        = "web-access"
  description = "Allow SSH, HTTP, and HTTPS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH (22)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (80)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (443)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "Web Server SecurityGroup"
    Owner = var.lord_of_terraform
  }
}

# -------------------- EC2 Instance --------------------
module "web_instance" {
  source               = "./modules/ec2_instance"
  ami_id               = data.aws_ami.latest_ubuntu.id
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.public_subnets[0]
  key_name             = "sergey-key-stockholm"
  security_group_ids   = [aws_security_group.web_sg.id]
  eip_allocation       = aws_eip.main.id
  attach_eip           = true
  user_data            = file("${path.module}/user_data2.sh")
  iam_instance_profile = aws_iam_instance_profile.ec2_backup_profile.name

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


#===========================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "main-vpc"
  cidr = "10.0.0.0/16"

  azs            = slice(data.aws_availability_zones.availability_zones.names, 0, 2)
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway = false
  single_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Name  = "main-vpc"
    Owner = var.lord_of_terraform
  }

  public_subnet_tags = {
    Name = "main-public-subnet"
  }

  igw_tags = {
    Name = "main-igw"
  }

  public_route_table_tags = {
    Name = "main-public-rt"
  }
}

# -------------------- S3 Backup Bucket --------------------
resource "aws_s3_bucket" "backups" {
  bucket = var.backup_bucket_name

  tags = {
    Name  = "Backup Bucket"
    Owner = var.lord_of_terraform
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups_lifecycle" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"

    filter {
      prefix = "" # apply to all objects
    }

    transition {
      days          = 7
      storage_class = "GLACIER"
    }

    expiration {
      days = 30
    }
  }
}

# -------------------- IAM Role for EC2 Backup Access --------------------
resource "aws_iam_role" "ec2_backup_role" {
  name = "EC2BackupS3Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "backup_s3_policy" {
  name = "BackupS3Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"],
      Resource = [
        "arn:aws:s3:::${var.backup_bucket_name}",
        "arn:aws:s3:::${var.backup_bucket_name}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_backup_policy" {
  role       = aws_iam_role.ec2_backup_role.name
  policy_arn = aws_iam_policy.backup_s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_backup_profile" {
  name = "EC2BackupInstanceProfile"
  role = aws_iam_role.ec2_backup_role.name
}

module "redis_oss" {
  source          = "./modules/redis"
  name            = "ghostfolio"
  owner           = var.lord_of_terraform
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
  allowed_sg_id   = aws_security_group.web_sg.id
  redis_user_name = var.redis_user_name
  redis_password  = var.redis_password
}
