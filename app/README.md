# Sample API

A minimal Python FastAPI application for testing the infrastructure end-to-end.

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /health` | ALB health check — always returns 200 |
| `GET /` | Basic status response |
| `GET /info` | Environment name + DB connectivity check |
| `GET /docs` | Auto-generated OpenAPI UI |

## Run Locally

```bash
cd app/sample-api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8080
```

Visit http://localhost:8080/docs for the interactive API documentation.

## Environment Variables

| Variable | Source | Description |
|---|---|---|
| `APP_ENV` | ECS task definition | Environment name (dev/staging/prod) |
| `PORT` | ECS task definition | Container port (8080) |
| `DB_SECRET` | ECS secrets injection | Full JSON from Secrets Manager `{project}/{env}/db-credentials` |
| `APP_SECRET` | ECS secrets injection | Full JSON from Secrets Manager `{project}/{env}/app-secrets` |

`DB_SECRET` JSON structure:
```json
{
  "username": "appuser",
  "password": "...",
  "host": "myapp-dev.xxxx.us-east-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "appdb",
  "engine": "postgres"
}
```

## Build and Push to ECR Manually

```bash
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1
PROJECT=myapp
ENV=dev

ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT-$ENV"

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

docker build -t "$ECR_URI:latest" .
docker push "$ECR_URI:latest"
```

## ECS Exec (Interactive Access)

```bash
# Get a shell inside a running task
aws ecs execute-command \
  --cluster myapp-dev \
  --task <TASK_ID> \
  --container app \
  --interactive \
  --command "/bin/bash"
```

Requires `enable_execute_command = true` on the ECS service (already set) and the ECS task role having `ssmmessages:*` permissions (already granted).
