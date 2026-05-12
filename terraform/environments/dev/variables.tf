variable "project" {
  description = "Short project slug (lowercase, no spaces) — used in all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID (used for IAM policies and S3 bucket naming)"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}

variable "container_image" {
  description = "Full ECR image URI including tag (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp-dev:latest)"
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

variable "enable_https" {
  description = "Enable HTTPS on the ALB (requires acm_certificate_arn)"
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS (required when enable_https=true)"
  type        = string
  default     = ""
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
  description = "Create the GitHub OIDC provider. Set true for the first environment in this account only."
  type        = bool
  default     = true
}
