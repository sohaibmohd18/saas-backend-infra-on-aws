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

variable "alert_email" {
  description = "Email address for SNS alert notifications (must confirm subscription)"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster (for alarm dimensions)"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service (for alarm dimensions)"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (from alb module output)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group (from alb module output)"
  type        = string
}

variable "db_instance_id" {
  description = "RDS instance identifier (for alarm dimensions)"
  type        = string
}

variable "db_max_connections" {
  description = "Maximum expected DB connections (alarm threshold at 80% of this value)"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
