variable "project" {
  description = "Short project slug used in resource names (no spaces, lowercase)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID (used to ensure globally unique S3 bucket name)"
  type        = string
}
