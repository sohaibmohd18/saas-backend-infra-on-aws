variable "project" {
  description = "Project slug used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without org prefix)"
  type        = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set to true in the first environment only (provider is account-scoped)."
  type        = bool
  default     = false
}

variable "db_secret_arn" {
  description = "ARN of the DB credentials secret in Secrets Manager"
  type        = string
}

variable "app_secret_arn" {
  description = "ARN of the app secrets secret in Secrets Manager"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
