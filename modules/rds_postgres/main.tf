resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "${var.name}-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier             = var.name
  engine                 = "postgres"
  engine_version         = "16.9"
  instance_class         = "db.t3.micro" # Free-tier eligible
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  skip_final_snapshot = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:05:00-Sun:06:00"
  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false

  tags = {
    Name = var.name
  }
}
