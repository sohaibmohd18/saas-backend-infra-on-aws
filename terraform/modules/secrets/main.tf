locals {
  name_prefix    = "${var.project}/${var.environment}"
  resource_prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# DB Password (generated, stored in Secrets Manager)
# ---------------------------------------------------------------------------

resource "random_password" "db_password" {
  length  = 32
  special = true
  # Restrict to chars safe in URL-format connection strings (postgresql://user:pass@host/db).
  # Excluded: @ / : ? # % [ ] { } < > — these break libpq connection URIs and some ORMs.
  override_special = "!()-_=+"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name_prefix}/db-credentials"
  description             = "PostgreSQL master credentials for ${var.project} ${var.environment}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name = "${local.resource_prefix}-db-credentials"
  }
}

# Initial secret version — host is populated by the RDS module after instance creation
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    port     = 5432
    dbname   = var.db_name
    host     = "" # Updated by rds module after instance is created
  })

  # Prevent Terraform from reverting the secret after the RDS module updates it with the host
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# App Secrets (placeholder — operators update with real values via AWS Console)
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${local.name_prefix}/app-secrets"
  description             = "Application secrets for ${var.project} ${var.environment} (API keys, tokens, etc.)"
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name = "${local.resource_prefix}-app-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    placeholder = "replace-me"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# SSM Parameters for non-sensitive config (free tier, no per-call cost)
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "db_port" {
  name  = "/${local.name_prefix}/db/port"
  type  = "String"
  value = "5432"

  tags = {
    Name = "${local.resource_prefix}-db-port"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${local.name_prefix}/db/name"
  type  = "String"
  value = var.db_name

  tags = {
    Name = "${local.resource_prefix}-db-name"
  }
}

resource "aws_ssm_parameter" "app_environment" {
  name  = "/${local.name_prefix}/app/environment"
  type  = "String"
  value = var.environment

  tags = {
    Name = "${local.resource_prefix}-app-environment"
  }
}
