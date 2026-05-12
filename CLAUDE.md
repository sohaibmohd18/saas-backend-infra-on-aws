# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

Production-ready SaaS backend AWS infrastructure using Terraform + ECS Fargate + RDS PostgreSQL. Three environments: dev, staging, prod. See [docs/architecture.md](docs/architecture.md) for the full architecture.

## Common Commands

### Terraform (run from an environment directory)

```bash
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Target a single module
terraform apply -var-file=terraform.tfvars -target=module.ecs

# Bootstrap state backend (once only)
cd terraform/backend/bootstrap
terraform init && terraform apply
```

### App (sample FastAPI)

```bash
cd app/sample-api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8080
```

### Manual ECR Push

```bash
ECR_URL=$(cd terraform/environments/dev && terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin "${ECR_URL%/*}"
docker build -t "$ECR_URL:latest" ./app
docker push "$ECR_URL:latest"
```

### Force ECS Redeployment

```bash
aws ecs update-service --cluster myapp-dev --service myapp-dev --force-new-deployment
aws ecs wait services-stable --cluster myapp-dev --services myapp-dev
```

### ECS Exec (interactive shell)

```bash
TASK=$(aws ecs list-tasks --cluster myapp-dev --service-name myapp-dev --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster myapp-dev --task $TASK --container app --interactive --command "/bin/bash"
```

## Architecture

```
Internet → ALB → ECS Fargate (private subnets) → RDS PostgreSQL (private DB subnets)
```

- **Networking**: 3 subnet tiers (public/private-app/private-db), NAT gateways, VPC endpoints in staging/prod
- **Compute**: ECS Fargate, auto-scaling on CPU (60%) and memory (70%), circuit breaker with rollback
- **CI/CD**: GitHub Actions + OIDC. No long-lived AWS keys. See `.github/workflows/`
- **Secrets**: Secrets Manager for credentials, SSM Parameters for non-sensitive config

## Module Map

| Module | Purpose | Key outputs |
|---|---|---|
| `vpc` | Networking, subnets, NAT, VPC endpoints | `vpc_id`, `*_subnet_ids`, `db_subnet_group_name` |
| `security` | All security groups (ALB, ECS, RDS) | `alb_sg_id`, `ecs_tasks_sg_id`, `rds_sg_id` |
| `secrets` | DB password generation, Secrets Manager, SSM params | `db_secret_arn`, `db_password`, `app_secret_arn` |
| `iam` | GitHub OIDC role, ECS execution + task roles | `github_actions_role_arn`, `ecs_task_execution_role_arn` |
| `ecr` | Container registry, lifecycle policy | `repository_url` |
| `rds` | PostgreSQL instance, parameter group | `db_endpoint`, `db_instance_id` |
| `alb` | Load balancer, target group, listeners | `alb_dns_name`, `alb_arn_suffix`, `target_group_arn` |
| `ecs` | Cluster, service, task def, auto-scaling | `cluster_name`, `service_name` |
| `monitoring` | CloudWatch alarms, dashboard, SNS | `sns_topic_arn`, `dashboard_url` |

## Naming Convention

`{project}-{environment}-{resource-type}` → e.g., `myapp-dev-alb`, `myapp-prod-ecs-task-execution`

Secrets Manager paths: `{project}/{environment}/db-credentials`, `{project}/{environment}/app-secrets`

## Critical Terraform Patterns

**ECS service lifecycle**: The ECS service has `lifecycle { ignore_changes = [task_definition, desired_count] }`. Without this, `terraform apply` reverts CI/CD deployments.

**OIDC provider**: Set `create_oidc_provider = true` only in dev (or whichever environment is applied first in the account). Set to `false` in staging and prod.

**First deploy sequence**: bootstrap → `terraform apply -target=module.secrets -target=module.iam -target=module.ecr` → push placeholder image → `terraform apply`

**DB host injection**: The secrets module creates the DB secret with an empty host. The RDS module writes the real endpoint to SSM param `/{project}/{env}/db/host`. The ECS task definition injects `DB_HOST` as a plain environment variable (sourced from `module.rds.db_host` in Terraform state) — the app reads it as an override over whatever host is in `DB_SECRET`. Never write the DB host back into Secrets Manager from Terraform; it overwrites externally rotated passwords.

**backend.hcl**: Committed file (no secrets). Contains S3 bucket + DynamoDB table names. Init: `terraform init -backend-config=backend.hcl`.

**terraform.tfvars**: Git-ignored (contains account IDs, emails). Only `*.tfvars.example` is committed. Use `-var-file=terraform.tfvars` locally. CI uses `TF_VAR_*` environment variables sourced from GitHub Secrets/Variables — no tfvars file is present in CI.

**GitHub Actions variables required**: Secrets: `AWS_ACCOUNT_ID`, `ACM_CERTIFICATE_ARN` (prod HTTPS). Variables: `PROJECT`, `AWS_REGION`, `GITHUB_ORG`, `GITHUB_REPO`, `ALERT_EMAIL`. See [docs/deployment.md](docs/deployment.md) for the full setup table.

## Environment Differences

| Setting | dev | staging | prod |
|---|---|---|---|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| AZs | 2 | 2 | 3 |
| Single NAT | true | true | false |
| VPC endpoints | false | true | true |
| RDS class | db.t3.micro | db.t3.medium | db.t3.large |
| Multi-AZ | false | false | true |
| FARGATE_SPOT | true | false | false |
| Min/max tasks | 1/3 | 2/10 | 2/50 |
