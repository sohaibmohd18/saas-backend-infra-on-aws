# Runbook

## Common Operational Tasks

### View Application Logs

```bash
# Stream live logs from ECS tasks
aws logs tail /ecs/myapp-dev --follow

# Query logs for errors (CloudWatch Logs Insights)
aws logs start-query \
  --log-group-name "/ecs/myapp-dev" \
  --start-time $(date -v-1H +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, message | filter level = "ERROR" | sort @timestamp desc | limit 50'
```

### Restart the Service (Force New Deployment)

```bash
aws ecs update-service \
  --cluster myapp-dev \
  --service myapp-dev \
  --force-new-deployment

aws ecs wait services-stable --cluster myapp-dev --services myapp-dev
```

### Scale Task Count Manually

```bash
# Temporarily scale up (Terraform will reset this on next apply)
aws ecs update-service \
  --cluster myapp-prod \
  --service myapp-prod \
  --desired-count 10
```

### Check Service Status

```bash
aws ecs describe-services \
  --cluster myapp-prod \
  --services myapp-prod \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}'
```

### Get a Shell in a Running Container (ECS Exec)

```bash
TASK=$(aws ecs list-tasks \
  --cluster myapp-dev \
  --service-name myapp-dev \
  --query 'taskArns[0]' \
  --output text)

aws ecs execute-command \
  --cluster myapp-dev \
  --task $TASK \
  --container app \
  --interactive \
  --command "/bin/bash"
```

## Alarm Response

### `myapp-dev-ecs-cpu-high`
CPU sustained above 80%. Check:
1. CloudWatch dashboard for traffic spike
2. `aws ecs describe-services` for running task count (auto-scaling should be adding tasks)
3. Application logs for inefficient queries or tight loops

### `myapp-dev-alb-5xx-high`
App is returning 5xx errors. Check:
1. ECS logs for exceptions: `aws logs tail /ecs/myapp-dev --follow`
2. ECS service events: `aws ecs describe-services --cluster myapp-dev --services myapp-dev`
3. If tasks are crash-looping, the circuit breaker will roll back automatically

### `myapp-dev-alb-unhealthy-hosts`
ALB can't reach any healthy targets. Check:
1. ECS service running count (may be 0 if tasks failed)
2. ECS task logs for startup errors
3. Security groups: ECS tasks SG must allow inbound on port 8080 from ALB SG

### `myapp-dev-rds-cpu-high`
RDS under load. Check:
1. RDS Performance Insights for slow queries
2. Connection count alarm — if connections are also high, consider PgBouncer
3. Upgrade RDS instance class if sustained

### `myapp-dev-rds-free-storage-low`
Less than 5 GB free. Note: RDS storage autoscaling is enabled (max 100 GB). This alarm fires if autoscaling is approaching its limit. Action: increase `max_allocated_storage` in the RDS module.

### `myapp-dev-rds-connections-high`
Connections approaching maximum. Check if ECS tasks are not closing connections properly. Consider connection pooling (PgBouncer).

## RDS Operations

### Connect to the Database

Use ECS Exec to get into a container, then connect:
```bash
# Inside the ECS container shell:
apt-get install -y postgresql-client

# Read credentials from environment
python3 -c "import json,os; c=json.loads(os.environ['DB_SECRET']); print(f\"host={c['host']} user={c['username']} dbname={c['dbname']}\")"

# Connect
psql -h <host> -U appuser -d appdb
```

### View Slow Queries

```bash
# In psql:
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Check Active Connections

```bash
SELECT count(*), state, wait_event_type, wait_event
FROM pg_stat_activity
GROUP BY state, wait_event_type, wait_event;
```

## Secrets Operations

### Update App Secrets and Redeploy

```bash
aws secretsmanager put-secret-value \
  --secret-id myapp/prod/app-secrets \
  --secret-string '{"stripe_key": "sk_live_new", "api_key": "..."}'

# Force tasks to restart and pick up new secret values
aws ecs update-service \
  --cluster myapp-prod \
  --service myapp-prod \
  --force-new-deployment

aws ecs wait services-stable --cluster myapp-prod --services myapp-prod
```

### Rotate the DB Password

Enable AWS managed rotation (recommended over manual):
```bash
aws secretsmanager rotate-secret \
  --secret-id myapp/prod/db-credentials \
  --rotation-rules AutomaticallyAfterDays=30
```

Note: This requires configuring a Lambda rotation function. Without it, rotate manually:
```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)

# 2. Update RDS master password
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod \
  --master-user-password "$NEW_PASS" \
  --apply-immediately

# 3. Update Secrets Manager
CURRENT=$(aws secretsmanager get-secret-value --secret-id myapp/prod/db-credentials --query SecretString --output text)
UPDATED=$(echo $CURRENT | python3 -c "import json,sys; c=json.load(sys.stdin); c['password']='$NEW_PASS'; print(json.dumps(c))")
aws secretsmanager put-secret-value --secret-id myapp/prod/db-credentials --secret-string "$UPDATED"

# 4. Restart ECS tasks
aws ecs update-service --cluster myapp-prod --service myapp-prod --force-new-deployment
```

## Terraform Operations

### Check Drift

```bash
cd terraform/environments/prod
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
```

A clean plan with "No changes" means infrastructure matches the Terraform state.

### Import Existing Resources

If a resource was created outside Terraform:
```bash
terraform import module.rds.aws_db_instance.main myapp-prod
```

### State Management

```bash
# List all resources in state
terraform state list

# Show a specific resource
terraform state show module.ecs.aws_ecs_service.app

# Remove a resource from state without deleting it (useful if importing elsewhere)
terraform state rm module.monitoring.aws_cloudwatch_dashboard.main
```
