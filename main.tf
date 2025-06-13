terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "0b9ec6a0-4338-4faf-b5d3-ae79aedd8089-terraform-state-bucket"
    key    = "terraform_state_test/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = var.region
}

# Declare the data source
data "aws_availability_zones" "availability_zones" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpcs" "my_vpcs" {}

data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (official Ubuntu images)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}


data "aws_route53_zone" "styrinov" {
  name         = var.my_domain
  private_zone = false
}


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


# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "main-vpc"
    Owner = var.lord_of_terraform
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name  = "main-igw"
    Owner = var.lord_of_terraform
  }
}

# Create a Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.availability_zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name  = "main-public-subnet"
    Owner = var.lord_of_terraform
  }
}

# Create a Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name  = "main-public-rt"
    Owner = var.lord_of_terraform
  }
}

# Create a Route in the Route Table
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web_sg" {
  name        = "web-access"
  description = "Allow SSH, HTTP, and HTTPS"
  vpc_id      = aws_vpc.main.id

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

module "web_instance" {
  source             = "./modules/ec2_instance"
  ami_id             = data.aws_ami.latest_ubuntu.id
  instance_type      = "t3.micro"
  subnet_id          = aws_subnet.public.id
  key_name           = "sergey-key-stockholm"
  security_group_ids = [aws_security_group.web_sg.id]
  eip_allocation     = aws_eip.main.id
  attach_eip         = true

  user_data = templatefile("${path.module}/user_data.sh.tpl2", {
    domain_name = "${var.subdomain}.${var.my_domain}"
  })

  tags = {
    Name  = "Web Server Build by Terraform"
    Owner = var.lord_of_terraform
  }

}
