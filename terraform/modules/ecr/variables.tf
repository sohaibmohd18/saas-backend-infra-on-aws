variable "project" {
  description = "Project slug used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ARN of the ECS task execution role (granted pull access)"
  type        = string
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role (granted push access)"
  type        = string
}

variable "force_delete" {
  description = "Delete the repository even if it contains images. Set true in dev so terraform destroy succeeds; false in prod to prevent accidental data loss."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
