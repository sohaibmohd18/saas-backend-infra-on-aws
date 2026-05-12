locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["a", "b"]
  single_nat_gateway  = true  # Single NAT in staging (prod uses one-per-AZ)
  enable_vpc_endpoints = true # Enable in staging to match prod behavior

  tags = local.common_tags
}

module "security" {
  source = "../../modules/security"

  project        = var.project
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  vpc_cidr       = module.vpc.vpc_cidr_block
  container_port = var.container_port

  tags = local.common_tags
}

module "secrets" {
  source = "../../modules/secrets"

  project                 = var.project
  environment             = var.environment
  db_name                 = "appdb"
  db_username             = "appuser"
  recovery_window_in_days = 7

  tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  project        = var.project
  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id
  github_org     = var.github_org
  github_repo    = var.github_repo

  create_oidc_provider = var.create_oidc_provider

  db_secret_arn  = module.secrets.db_secret_arn
  app_secret_arn = module.secrets.app_secret_arn

  tags = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  project                 = var.project
  environment             = var.environment
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  github_actions_role_arn = module.iam.github_actions_role_arn
  force_delete            = true # Allow terraform destroy in staging

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  project      = var.project
  environment  = var.environment

  db_engine_version    = "15.7"
  db_instance_class    = "db.t3.medium"
  db_name              = "appdb"
  db_username          = module.secrets.db_username
  db_password          = module.secrets.db_password
  db_subnet_group_name = module.vpc.db_subnet_group_name
  rds_sg_id            = module.security.rds_sg_id
  db_secret_arn        = module.secrets.db_secret_arn

  multi_az              = false
  deletion_protection   = false
  backup_retention_days = 7

  tags = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  container_port    = var.container_port

  enable_https        = var.enable_https
  acm_certificate_arn = var.acm_certificate_arn
  deletion_protection = false

  tags = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  private_app_subnet_ids  = module.vpc.private_app_subnet_ids
  ecs_tasks_sg_id         = module.security.ecs_tasks_sg_id
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn           = module.iam.ecs_task_role_arn

  container_image = var.container_image
  container_port  = var.container_port
  task_cpu        = 512
  task_memory     = 1024
  min_capacity    = 2
  max_capacity    = 10
  use_spot        = false # No FARGATE_SPOT in staging — mirrors prod reliability

  target_group_arn   = module.alb.target_group_arn
  db_secret_arn      = module.secrets.db_secret_arn
  app_secret_arn     = module.secrets.app_secret_arn
  db_host            = module.rds.db_host
  log_retention_days = 30

  tags = local.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  alert_email        = var.alert_email
  log_retention_days = 30

  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name

  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  db_instance_id     = module.rds.db_instance_id
  db_max_connections = 400 # db.t3.medium PostgreSQL approximate max

  tags = local.common_tags
}
