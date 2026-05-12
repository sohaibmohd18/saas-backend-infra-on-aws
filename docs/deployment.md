# Deployment Guide

## Prerequisites

- AWS CLI configured with admin access to your AWS account
- Terraform >= 1.6 installed
- Docker installed
- GitHub repository with Actions enabled

## Step 1: Bootstrap the Remote State Backend

This only needs to be done once per AWS account.

```bash
cd terraform/backend/bootstrap

# Create a terraform.tfvars file:
cat > terraform.tfvars <<EOF
project        = "myapp"         # Replace with your project slug
aws_region     = "us-east-1"    # Replace with your region
aws_account_id = "123456789012" # Replace with your AWS account ID
EOF

terraform init
terraform apply
```

Note the outputs — you'll need them:
```
state_bucket_name  = "myapp-terraform-state-123456789012"
dynamodb_table_name = "myapp-terraform-locks"
```

## Step 2: Configure backend.hcl Files

Update all three `backend.hcl` files with the actual values:

```bash
# Replace REPLACE_WITH_ACCOUNT_ID in all three files
sed -i '' 's/REPLACE_WITH_ACCOUNT_ID/123456789012/g' \
  terraform/environments/dev/backend.hcl \
  terraform/environments/staging/backend.hcl \
  terraform/environments/prod/backend.hcl
```

Commit these files — they contain no secrets.

## Step 3: Configure GitHub Actions Variables and Secrets

Go to **GitHub → Settings → Secrets and variables → Actions** and add:

**Repository Variables** (Settings → Variables):
| Name | Example value | Description |
|------|---------------|-------------|
| `PROJECT` | `myapp` | Short project slug, must match Terraform resources |
| `AWS_REGION` | `us-east-1` | AWS region |
| `GITHUB_ORG` | `your-org` | GitHub organization or username |
| `GITHUB_REPO` | `saas-backend-infra-on-aws` | Repository name |
| `ALERT_EMAIL` | `alerts@example.com` | Email for CloudWatch alarm notifications |

**Repository Secrets** (Settings → Secrets):
| Name | Description |
|------|-------------|
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `ACM_CERTIFICATE_ARN` | ACM certificate ARN (required before enabling HTTPS in prod; leave unset until then) |

GitHub Actions workflows use `TF_VAR_*` environment variables — no `terraform.tfvars` file is needed in CI.

## Step 4: Create Local terraform.tfvars Files (for local development)

For running Terraform locally, copy the example and fill in your values:

```bash
cp terraform/environments/dev/terraform.tfvars.example \
   terraform/environments/dev/terraform.tfvars
```

Edit `terraform.tfvars` with your AWS account ID, GitHub org, repo, and alert email.

**Do not commit `terraform.tfvars` files** — they are git-ignored. CI uses GitHub Secrets/Variables instead.

## Step 5: Bootstrap ECR and IAM (First Apply)

The ECR repo must exist before you can push an image, and the image must exist before ECS can start.

```bash
cd terraform/environments/dev

terraform init -backend-config=backend.hcl

# Apply only ECR and IAM first
terraform apply \
  -var-file=terraform.tfvars \
  -target=module.secrets \
  -target=module.iam \
  -target=module.ecr
```

## Step 6: Push a Placeholder Image

```bash
# Get ECR repo URL from terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)
AWS_REGION="us-east-1"

# Authenticate to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin "${ECR_URL%/*}"

# Push a placeholder so ECS has an image to pull on first launch
docker pull python:3.12-slim
docker tag python:3.12-slim "$ECR_URL:latest"
docker push "$ECR_URL:latest"
```

## Step 7: Full Apply

```bash
# Update container_image in terraform.tfvars with the ECR URL
# Then apply everything
terraform apply -var-file=terraform.tfvars
```

After apply completes, get the ALB DNS name:
```bash
terraform output alb_dns_name
```

Test the health endpoint:
```bash
curl http://$(terraform output -raw alb_dns_name)/health
# Expected: {"status":"healthy"}
```

## Step 8: Confirm SNS Email Subscription

Check your inbox for an email from AWS SNS and click **Confirm subscription**. Alarms won't deliver until you do this.

## Step 9: Build and Push the Real App Image

```bash
cd ../../..  # back to repo root

# Build and push the actual application
ECR_URL=$(cd terraform/environments/dev && terraform output -raw ecr_repository_url)
docker build -t "$ECR_URL:latest" ./app
docker push "$ECR_URL:latest"

# Force ECS to pick up the new image
aws ecs update-service \
  --cluster myapp-dev \
  --service myapp-dev \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster myapp-dev \
  --services myapp-dev
```

## Staging and Prod Deployment

After dev is working, bootstrap staging locally:

```bash
cd terraform/environments/staging

# Create local tfvars (git-ignored; only needed for local runs)
cp terraform.tfvars.example terraform.tfvars
# Edit: set create_oidc_provider=false (OIDC provider already exists from dev)

terraform init -backend-config=backend.hcl

# Bootstrap ECR/IAM first, push placeholder image, then full apply
terraform apply -target=module.secrets -target=module.iam -target=module.ecr -var-file=terraform.tfvars
# (push placeholder image as in Step 6, substituting the staging ECR URL)
terraform apply -var-file=terraform.tfvars
```

Subsequent deploys go through CI — merges to main trigger `terraform-apply.yml` which runs staging after dev (with approval gate), then prod after staging (with approval gate).

## CI/CD After Initial Setup

Once the infrastructure is up:

1. Push changes to `terraform/**` → triggers `terraform-plan.yml` on PR, `terraform-apply.yml` on merge
2. Push changes to `app/**` → triggers `app-deploy.yml` (builds, pushes to ECR, updates ECS)

The `staging` and `prod` GitHub environments must have required reviewers configured for protection rules to work.

## Environment Promotion Flow

```
app/** change → build image → deploy dev (auto)
                            → approval → deploy staging
                            → approval → deploy prod
```

## Rollback

### Automatic Rollback
ECS deployment circuit breaker is enabled. If a deployment fails health checks within 10 minutes, ECS automatically reverts to the previous task definition.

### Manual Rollback
```bash
# Find the previous task definition
aws ecs list-task-definitions --family-prefix myapp-prod --sort DESC

# Update the service to use it
aws ecs update-service \
  --cluster myapp-prod \
  --service myapp-prod \
  --task-definition myapp-prod:42  # previous version number

aws ecs wait services-stable --cluster myapp-prod --services myapp-prod
```

## Destroying Dev Safely

```bash
cd terraform/environments/dev

# Requires local terraform.tfvars (see Step 4); deletion_protection=false in dev by default
terraform destroy -var-file=terraform.tfvars

# The S3 state bucket and DynamoDB lock table are NOT destroyed by this.
# They are managed by the bootstrap module with prevent_destroy = true.
```
