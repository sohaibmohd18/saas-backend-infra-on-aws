locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-pg15"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    # Log queries taking longer than 1 second; log_duration=1 logs EVERY statement and is cost-prohibitive
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${local.name_prefix}-pg15"
  }
}

resource "aws_db_instance" "main" {
  identifier = local.name_prefix

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  storage_type          = "gp3"
  allocated_storage     = 20
  max_allocated_storage = 100 # Enable storage autoscaling up to 100 GB

  storage_encrypted = true
  multi_az          = var.multi_az

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.name_prefix}-final-snapshot" : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # 7 days is free tier

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true
  publicly_accessible        = false

  tags = {
    Name = local.name_prefix
  }

  # After initial creation, manage password via Secrets Manager rotation, not Terraform
  lifecycle {
    ignore_changes = [password]
  }
}

# ---------------------------------------------------------------------------
# SSM Parameter for DB host (non-sensitive, fast/free to read from app)
# ---------------------------------------------------------------------------
# The DB host is injected as a plain env var (DB_HOST) into ECS tasks via
# the environment block in the task definition. Writing it to SSM also allows
# operators to look it up without Terraform state access.
# NOTE: We do NOT update the Secrets Manager secret here. The secrets module
# creates the initial secret (with ignore_changes) and owns it exclusively.
# Writing the password back here would clobber external rotation.

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project}/${var.environment}/db/host"
  type  = "String"
  value = aws_db_instance.main.address

  tags = {
    Name = "${local.name_prefix}-db-host"
  }
}
