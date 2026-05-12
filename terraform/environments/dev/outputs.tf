output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the ALB — use this to access the application"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL — use this as the base for container_image"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions — add this as a GitHub repository variable"
  value       = module.iam.github_actions_role_arn
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch monitoring dashboard"
  value       = module.monitoring.dashboard_url
}
