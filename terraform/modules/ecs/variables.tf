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

variable "private_app_subnet_ids" {
  description = "IDs of private app subnets where ECS tasks run"
  type        = list(string)
}

variable "ecs_tasks_sg_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "container_image" {
  description = "Full ECR image URI including tag (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp-dev:latest)"
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "Fargate task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 3
}

variable "use_spot" {
  description = "Use FARGATE_SPOT capacity provider (70% cheaper but tasks may be interrupted)"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the DB credentials secret (injected into container at launch)"
  type        = string
}

variable "app_secret_arn" {
  description = "ARN of the app secrets (injected into container at launch)"
  type        = string
}

variable "db_host" {
  description = "RDS instance hostname — injected as DB_HOST env var (avoids writing password back to Secrets Manager on every apply)"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
