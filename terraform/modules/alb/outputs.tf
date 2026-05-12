output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB (use this to access the application)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB (for alias records)"
  value       = aws_lb.main.zone_id
}

output "alb_name" {
  description = "Name of the ALB"
  value       = aws_lb.main.name
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB (used in CloudWatch metric dimensions)"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group (used in CloudWatch metric dimensions)"
  value       = aws_lb_target_group.app.arn_suffix
}

output "http_listener_arn" {
  description = "ARN of the HTTP:80 listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS:443 listener (empty string when enable_https=false)"
  value       = var.enable_https ? aws_lb_listener.https[0].arn : ""
}
