variable "project" {
  description = "Project slug used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of AZ suffixes to use (e.g. [\"a\", \"b\", \"c\"])"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (saves cost in dev; use false for prod HA)"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Create interface VPC endpoints for ECR, Secrets Manager, CloudWatch Logs, SSM"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
