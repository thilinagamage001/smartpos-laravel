resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name    = "${var.project}-db-subnet-group"
    Project = var.project
  }
}

resource "aws_db_instance" "postgres" {
  identifier            = "${var.project}-db"
  engine                = "postgres"
  engine_version        = "16"
  instance_class        = var.db_instance_class
  allocated_storage     = 20
  max_allocated_storage = 0 # Disable autoscaling so storage never exceeds 20GB Free Tier cap
  storage_type          = "gp2"
  storage_encrypted     = true
  multi_az              = false # AWS Free Tier covers Single-AZ only

  db_name  = "smartpos"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_id]
  publicly_accessible    = false

  # Keep 1-day backup and skip final snapshot to stay strictly within 20GB Free Tier backup storage
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name    = "${var.project}-rds"
    Project = var.project
  }
}
