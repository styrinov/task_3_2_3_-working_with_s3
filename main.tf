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

resource "aws_route53_record" "bastion_dns" {
  count   = var.ver.env == "dev" ? 1 : 0
  zone_id = data.aws_route53_zone.styrinov.zone_id

  name    = "bastion.${var.ver.env}.${var.my_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.bastion_eip[0].public_ip]
}


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
