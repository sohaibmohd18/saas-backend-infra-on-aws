# saas-backend-infra-on-aws

Production-ready AWS SaaS backend infrastructure built with Terraform. Handles 1,000 users on day one, scales to 100,000 without a rewrite.

## Architecture

```
Internet → ALB (public subnets) → ECS Fargate (private app subnets) → RDS PostgreSQL (private DB subnets)
```

- **Compute**: ECS Fargate with auto-scaling (CPU and memory target tracking)
- **Database**: RDS PostgreSQL 15 with encryption, automated backups, Multi-AZ (prod)
- **Networking**: Custom VPC, three subnet tiers, NAT gateways, optional VPC endpoints
- **Security**: IAM least privilege, no public IPs on ECS/RDS, Secrets Manager for credentials
- **CI/CD**: GitHub Actions with OIDC (no long-lived AWS keys)
- **Monitoring**: CloudWatch dashboard, alarms for ECS/ALB/RDS, SNS email alerts

See [docs/architecture.md](docs/architecture.md) for diagrams and design decisions.

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured with admin access
- Docker
- GitHub repository with Actions enabled

## Quick Start

### 1. Bootstrap Remote State (once per account)

```bash
cd terraform/backend/bootstrap
cp terraform.tfvars.example terraform.tfvars  # fill in project, region, account_id
terraform init && terraform apply
```

### 2. Configure Environments

```bash
# Update bucket name and account ID in backend.hcl files
# Then create your tfvars from the example:
cp terraform/environments/dev/terraform.tfvars.example \
   terraform/environments/dev/terraform.tfvars
# Edit: project, aws_account_id, alert_email, github_org, github_repo
```

### 3. Bootstrap ECR and IAM

```bash
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform apply -var-file=terraform.tfvars \
  -target=module.secrets -target=module.iam -target=module.ecr
```

### 4. Push Placeholder Image

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin "${ECR_URL%/*}"
docker pull python:3.12-slim
docker tag python:3.12-slim "$ECR_URL:latest"
docker push "$ECR_URL:latest"
```

### 5. Deploy Full Infrastructure

```bash
terraform apply -var-file=terraform.tfvars
curl http://$(terraform output -raw alb_dns_name)/health
# {"status":"healthy"}
```

For complete step-by-step instructions see [docs/deployment.md](docs/deployment.md).

## Repository Structure

```
.
├── .github/workflows/
│   ├── terraform-plan.yml    # Plans on PRs to main
│   ├── terraform-apply.yml   # Applies on push to main (staging/prod need approval)
│   └── app-deploy.yml        # Builds image, deploys to ECS
├── terraform/
│   ├── backend/bootstrap/    # S3 + DynamoDB for remote state (apply once)
│   ├── modules/              # Reusable modules: vpc, security, iam, secrets,
│   │   │                     # ecr, rds, alb, ecs, monitoring
│   └── environments/
│       ├── dev/              # Single NAT, FARGATE_SPOT, db.t3.micro
│       ├── staging/          # VPC endpoints, db.t3.medium
│       └── prod/             # Multi-NAT, Multi-AZ RDS, deletion_protection
├── app/
│   ├── Dockerfile
│   └── sample-api/           # Python FastAPI: GET /, /health, /info
└── docs/
    ├── architecture.md
    ├── deployment.md
    ├── scaling.md
    ├── security.md
    └── runbook.md
```

## GitHub Configuration

### Required Secrets
| Secret | Value |
|---|---|
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `ACM_CERTIFICATE_ARN` | ACM certificate ARN (required before enabling HTTPS in prod) |

### Required Variables
| Variable | Value |
|---|---|
| `PROJECT` | Your project slug (e.g. `myapp`) |
| `AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `GITHUB_ORG` | GitHub organization or username |
| `GITHUB_REPO` | Repository name (without org prefix) |
| `ALERT_EMAIL` | Email address for CloudWatch alarm notifications |

### Required Environments
Create `staging` and `prod` environments in GitHub Settings → Environments and add required reviewers for deployment protection.

### GitHub OIDC Setup
The IAM role (`{project}-github-actions`) is created by Terraform. After the first `terraform apply` in dev, get the role ARN:
```bash
terraform output github_actions_role_arn
```
No additional GitHub configuration needed — the role ARN is constructed from `AWS_ACCOUNT_ID` and `PROJECT` in the workflow files.

## Naming Convention

All resources follow `{project}-{environment}-{resource-type}`, e.g. `myapp-prod-alb`, `myapp-dev-ecs-task-execution`.

Secrets Manager paths: `{project}/{environment}/db-credentials` and `{project}/{environment}/app-secrets`.

## Documentation

| Doc | Contents |
|---|---|
| [Architecture](docs/architecture.md) | Diagrams, design decisions, security matrix |
| [Deployment](docs/deployment.md) | Bootstrap procedure, first deploy, rollback |
| [Scaling](docs/scaling.md) | Auto-scaling config, RDS upgrade path, 100k users |
| [Security](docs/security.md) | IAM roles, secrets rotation, ECS Exec access |
| [Runbook](docs/runbook.md) | Day-two ops, alarm response, Terraform state |

## License

Apache 2.0 — see [LICENSE](LICENSE).
