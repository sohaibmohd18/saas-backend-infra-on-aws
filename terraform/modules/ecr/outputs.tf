output "repository_url" {
  description = "Full URI of the ECR repository (use as container_image base)"
  value       = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.app.name
}
