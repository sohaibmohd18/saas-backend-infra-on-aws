output "db_secret_arn" {
  description = "ARN of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_secret_name" {
  description = "Name of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "db_password" {
  description = "Generated database password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}

output "db_username" {
  description = "Database master username"
  value       = var.db_username
}

output "app_secret_arn" {
  description = "ARN of the app secrets secret"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "app_secret_name" {
  description = "Name of the app secrets secret"
  value       = aws_secretsmanager_secret.app_secrets.name
}
