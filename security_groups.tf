resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow PostgreSQL access"
  vpc_id      = module.vpc.vpc_id

  #cidr_blocks = ["10.0.0.0/16"] # or just from EC2's SG if you want tighter control
  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = compact([
      aws_security_group.web_sg.id,
      var.ver.env == "dev" ? aws_security_group.bastion_sg[0].id : null
    ])
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "rds-sg"
    Owner = var.lord_of_terraform
  }
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

resource "aws_security_group" "bastion_sg" {
  count       = var.ver.env == "dev" ? 1 : 0
  name        = "bastion-sg"
  description = "Allow SSH access for Bastion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Or ["YOUR_DEV_TEAM_IP/32"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "bastion-sg"
    Owner = var.lord_of_terraform
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP and HTTPS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "alb-sg"
    Owner = var.lord_of_terraform
  }
}
