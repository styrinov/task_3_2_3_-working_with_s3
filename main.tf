
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "main-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.availability_zones.names, 0, 2)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

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

module "postgres_rds" {
  source = "./modules/rds_postgres"

  name                   = "my-postgres"
  db_name                = "ghostfolio"
  db_user                = "ghostfolio"
  db_password            = var.db_password
  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}


module "web_asg" {
  source             = "./modules/ec2_autoscaling_group"
  name               = "ghostfolio"
  ami_id             = "ami-052c508c0fad5d7cd"
  instance_type      = "t3.micro"
  key_name           = var.key_name
  security_group_ids = [aws_security_group.web_sg.id]
  subnet_ids         = module.vpc.public_subnets
  desired_capacity   = 2
  min_size           = 1
  max_size           = 3
  target_group_arns  = [module.web_alb.target_group_arn]
  #user_data          = file("${path.root}/asg_user_data.sh")
  user_data          = base64encode(file("${path.module}/asg_user_data.sh"))

  tags = {
    Owner = var.lord_of_terraform
  }
}

module "web_alb" {
  source            = "./modules/alb"
  name              = "ghostfolio"
  vpc_id            = module.vpc.vpc_id
  subnets           = module.vpc.public_subnets
  security_group_id = aws_security_group.alb_sg.id
  certificate_arn   = aws_acm_certificate.web_cert.arn
  tags = {
    Owner = var.lord_of_terraform
  }
}

