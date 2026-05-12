output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}

output "cloudwatch_dashboard_url" {
  value = module.monitoring.dashboard_url
}
