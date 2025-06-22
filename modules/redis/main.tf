resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name  = "${var.name}-subnet-group"
    Owner = var.owner
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Redis access"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis TCP access"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.allowed_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.name}-redis-sg"
    Owner = var.owner
  }
}

resource "aws_elasticache_user" "this" {
  user_id       = var.redis_user_name
  user_name     = var.redis_user_name
  engine        = "REDIS"
  passwords     = [var.redis_password]
  access_string = "on ~* +@all"

  authentication_mode {
    type = "password"
  }

  tags = {
    Name  = "${var.name}-user"
    Owner = var.owner
  }
}

resource "aws_elasticache_user_group" "this" {
  user_group_id = "${var.name}-user-group"
  engine        = "REDIS"
  user_ids = [
    "default",
    aws_elasticache_user.this.user_id
  ]

  tags = {
    Name  = "${var.name}-user-group"
    Owner = var.owner
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Redis for ${var.name} - via terraform"

  engine                  = "redis"
  engine_version          = "6.2"
  node_type               = "cache.t4g.micro"
  num_node_groups         = 1
  replicas_per_node_group = 0

  port = 6379

  #parameter_group_name = "default.redis6.x"
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  security_group_ids   = [aws_security_group.this.id]
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  user_group_ids       = [aws_elasticache_user_group.this.user_group_id]

  automatic_failover_enabled = false
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  depends_on = [
    aws_cloudwatch_log_group.redis_slow_log,
    aws_cloudwatch_log_group.redis_engine_log
  ]

  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    log_format       = "text"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    log_format       = "text"
    log_type         = "engine-log"
  }

  tags = {
    Name  = "${var.name}-redis-rg-terraform"
    Owner = var.owner
  }
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.name}-redis6"
  family = "redis6.x"

  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000" # log commands slower than 10ms
  }

  parameter {
    name  = "slowlog-max-len"
    value = "128" # max number of slowlog entries
  }
}

resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/ghostfolio-slow-log"
  retention_in_days = 14

  tags = {
    Name  = "ghostfolio-redis-slow-log"
    Owner = var.owner
  }
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/ghostfolio-engine-log"
  retention_in_days = 14

  tags = {
    Name  = "ghostfolio-redis-engine-log"
    Owner = var.owner
  }
}


