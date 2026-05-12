# Architecture

## Overview

Three-tier architecture on AWS ECS Fargate with a PostgreSQL RDS backend, fronted by an Application Load Balancer.

```
Internet
    │
    ▼
┌─────────────────────────────────────────────┐
│  Public Subnets (us-east-1a, 1b, 1c)        │
│  ┌──────────────────────────────────────┐    │
│  │  Application Load Balancer (ALB)     │    │
│  │  HTTP:80 → redirect (HTTPS) or fwd   │    │
│  │  HTTPS:443 → forward to target group │    │
│  └──────────────┬───────────────────────┘    │
└─────────────────┼───────────────────────────┘
                  │
┌─────────────────┼───────────────────────────┐
│  Private App Subnets                         │
│  ┌──────────────▼───────────────────────┐    │
│  │  ECS Fargate Tasks (port 8080)        │    │
│  │  Auto Scaling: 2–50 tasks (prod)      │    │
│  │  CPU target: 60% | Mem target: 70%    │    │
│  └──────────────┬───────────────────────┘    │
└─────────────────┼───────────────────────────┘
                  │
┌─────────────────┼───────────────────────────┐
│  Private DB Subnets                          │
│  ┌──────────────▼───────────────────────┐    │
│  │  RDS PostgreSQL 15                    │    │
│  │  Multi-AZ (prod) | Single (dev/stg)   │    │
│  │  Storage autoscaling 20→100 GB        │    │
│  └──────────────────────────────────────┘    │
└─────────────────────────────────────────────┘

Outbound (ECS → Internet):
  dev: via NAT Gateway
  staging/prod: via NAT Gateway + VPC Endpoints (ECR, Secrets Manager, CW Logs, SSM)
```

## VPC Subnet Layout

Each environment uses a non-overlapping CIDR to allow future VPC peering.

| Environment | VPC CIDR | Public | Private App | Private DB |
|---|---|---|---|---|
| dev | 10.0.0.0/16 | 10.0.0.x/24, 10.0.1.x/24 | 10.0.10.x/24, 10.0.11.x/24 | 10.0.20.x/24, 10.0.21.x/24 |
| staging | 10.1.0.0/16 | 10.1.0.x/24, 10.1.1.x/24 | 10.1.10.x/24, 10.1.11.x/24 | 10.1.20.x/24, 10.1.21.x/24 |
| prod | 10.2.0.0/16 | 10.2.0.x–2.x/24 | 10.2.10.x–12.x/24 | 10.2.20.x–22.x/24 |

## Module Dependency Graph

```
bootstrap → (S3 + DynamoDB, applied once)

vpc ─────────────────────────────────────────────┐
security (depends on vpc.vpc_id, vpc.cidr)       │
secrets                                           │
iam (depends on secrets.*_arn)                    │
ecr (depends on iam.execution_role, iam.gh_role)  │
rds (depends on vpc.db_subnet_group, secrets.*,   │
     security.rds_sg)                             │
alb (depends on vpc.public_subnets,               │
     security.alb_sg)                             │
ecs (depends on vpc.private_subnets,              │
     security.ecs_sg, iam.*, alb.tg_arn,          │
     secrets.*)                                   │
monitoring (depends on ecs.cluster/service,       │
            alb.arn_suffix, rds.instance_id)      │
```

## Security Boundary Matrix

| Source | Destination | Port | Allowed |
|---|---|---|---|
| Internet | ALB | 80, 443 | ✅ |
| ALB | ECS tasks | 8080 | ✅ |
| ECS tasks | RDS | 5432 | ✅ |
| ECS tasks | Secrets Manager | 443 | ✅ (via NAT or VPC endpoint) |
| ECS tasks | ECR | 443 | ✅ (via NAT or VPC endpoint) |
| Internet | ECS tasks | any | ❌ |
| Internet | RDS | any | ❌ |
| ECS tasks | ECS tasks | any | ❌ |

## Key Design Decisions

**NAT Gateway strategy**: Dev uses a single NAT (~$32/month), prod uses one per AZ ($96/month) so an AZ failure doesn't affect outbound traffic from other AZs.

**VPC Endpoints**: Disabled in dev (cost). Enabled in staging and prod for ECR API, ECR DKR, Secrets Manager, CloudWatch Logs, SSM, and SSM Messages. Keeps container pulls and secret fetches off the public internet; reduces NAT costs at scale.

**FARGATE_SPOT in dev**: Enabled in dev for ~70% cost savings. Tasks may be interrupted with 2-minute notice. Not used in staging or prod.

**ECS lifecycle ignore_changes**: The ECS service ignores changes to `task_definition` and `desired_count` in Terraform state. Without this, `terraform apply` would revert CI/CD deployments every time it runs.

**Secrets Manager vs SSM**: Sensitive values (DB password, API keys) are in Secrets Manager. Non-sensitive config (DB host, port, name, environment) is in SSM Standard Parameters (free, no per-call cost).

**Secrets circular dependency resolution**: The secrets module creates the DB secret shell with the password but an empty host. The RDS module creates the instance and then updates the secret with the actual endpoint in a separate `aws_secretsmanager_secret_version` resource. Apps should read DB host from SSM (`/{project}/{env}/db/host`) to avoid depending on the secrets update timing.

## Capacity Planning

| Users | Tasks | CPU | Memory | RDS Class | Notes |
|---|---|---|---|---|---|
| 1,000 | 2 | 512 | 1024 MB | db.t3.medium | Baseline config |
| 10,000 | 4–8 | 1024 | 2048 MB | db.t3.large | Auto-scales |
| 50,000 | 10–20 | 2048 | 4096 MB | db.r6g.large | Upgrade instance class |
| 100,000 | 20–50 | 2048 | 4096 MB | db.r6g.xlarge + read replica | Consider connection pooling (PgBouncer) |
