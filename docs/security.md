# Security

## IAM Architecture

### GitHub Actions Role (`{project}-github-actions`)

Trust policy allows only requests from `token.actions.githubusercontent.com` with:
- `aud = sts.amazonaws.com`
- `sub = repo:{org}/{repo}:*` (scoped to your specific repository)

The `*` at the end allows both PR branch refs and main branch refs. To tighten further, create separate plan (PR) and apply (main) roles — the plan role would have `sub: repo:{org}/{repo}:ref:refs/pull/*` with read-only state access, and the apply role `sub: repo:{org}/{repo}:ref:refs/heads/main`.

The GitHub Actions role has:
- Full Terraform state backend access (S3 + DynamoDB)
- ECR push permissions (scoped to `{project}-*` repositories)
- ECS update permissions
- PassRole for the two ECS roles only
- Broad infra management permissions (required for `terraform apply`)

### ECS Task Execution Role (`{project}-{env}-ecs-task-execution`)

Used by the ECS agent (not your code) to:
- Pull images from ECR (via managed policy `AmazonECSTaskExecutionRolePolicy`)
- Read the DB and app secrets from Secrets Manager (scoped to specific secret ARNs)

Your application code cannot assume this role.

### ECS Task Role (`{project}-{env}-ecs-task`)

Assumed by your running application containers:
- Read Secrets Manager secrets (for runtime secret access)
- SSM messages (for ECS Exec / interactive debugging)

This role should be extended with only the AWS services your app needs (S3, SQS, etc.).

## Secrets Management

DB credentials are stored in Secrets Manager at `{project}/{environment}/db-credentials`. The JSON structure:
```json
{
  "username": "appuser",
  "password": "...",
  "host": "myapp-dev.xxxx.rds.amazonaws.com",
  "port": 5432,
  "dbname": "appdb",
  "engine": "postgres"
}
```

The full secret is injected into the `DB_SECRET` environment variable at ECS task launch. Your app parses it with `json.loads(os.environ["DB_SECRET"])`.

App-specific secrets (API keys, tokens) go in `{project}/{environment}/app-secrets`. Update them via:
```bash
aws secretsmanager put-secret-value \
  --secret-id myapp/dev/app-secrets \
  --secret-string '{"stripe_key": "sk_live_...", "sendgrid_key": "..."}'
```

After updating a secret, force a new ECS deployment:
```bash
aws ecs update-service --cluster myapp-dev --service myapp-dev --force-new-deployment
```

## Network Security

- ALB is the only internet-facing resource
- ECS tasks have no public IP addresses (`assign_public_ip = false`)
- RDS has `publicly_accessible = false` and lives in private DB subnets
- Security groups enforce least-privilege:
  - ECS tasks accept traffic only from the ALB SG on port 8080
  - RDS accepts traffic only from the ECS tasks SG on port 5432
- All traffic between ECS and AWS services (ECR, Secrets Manager, CloudWatch, SSM) goes through VPC endpoints in staging/prod, never traversing the public internet

## Encryption

- RDS: `storage_encrypted = true` (AES-256 at rest)
- S3 state bucket: server-side encryption with AES-256
- Secrets Manager: encrypted at rest by default using AWS managed key
- All data in transit uses TLS (enforced on the state S3 bucket by bucket policy)
- ALB: TLS 1.3 preferred, TLS 1.2 minimum (`ELBSecurityPolicy-TLS13-1-2-2021-06`)

## ECS Exec (Interactive Access)

ECS Exec provides shell access to running containers without a bastion host:

```bash
# List running tasks
aws ecs list-tasks --cluster myapp-dev --service-name myapp-dev

# Get a shell
aws ecs execute-command \
  --cluster myapp-dev \
  --task <TASK_ARN> \
  --container app \
  --interactive \
  --command "/bin/bash"
```

Requirements (already configured):
1. `enable_execute_command = true` on the ECS service
2. `ssmmessages:*` permissions on the ECS task role
3. SSM agent in the container (included in `python:3.12-slim` base image)
4. Your IAM user/role must have `ecs:ExecuteCommand` permission

In prod environments with VPC endpoints, SSM traffic stays within the VPC.

## Checklist Before Going to Production

- [ ] ACM certificate provisioned and ARN set in `terraform.tfvars`
- [ ] `enable_https = true` in prod `main.tf`
- [ ] SNS email subscription confirmed
- [ ] CloudWatch alarms are in OK state after initial deploy
- [ ] GitHub environments (`staging`, `prod`) have required reviewers configured
- [ ] `app_secrets` updated with real API keys via AWS Console or CLI
- [ ] RDS `deletion_protection = true` (already set in prod `main.tf`)
- [ ] Test ECS Exec access from a developer machine
- [ ] Verify `/health` returns 200 from the public ALB DNS
- [ ] Confirm CloudWatch dashboard shows metrics flowing
- [ ] Review IAM GitHub Actions role trust policy — tighten `sub` condition if needed
