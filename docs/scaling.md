# Scaling Guide

## Auto Scaling (Built In)

ECS Fargate auto-scales based on CPU and memory target tracking:
- Scale out when average CPU > 60% or memory > 70%
- Scale in when below those targets for 5 minutes (300s cooldown)
- Scale out cooldown: 60 seconds (fast scale-out)

Current limits by environment:

| Environment | Min Tasks | Max Tasks | CPU | Memory |
|---|---|---|---|---|
| dev | 1 | 3 | 256 | 512 MB |
| staging | 2 | 10 | 512 | 1024 MB |
| prod | 2 | 50 | 1024 | 2048 MB |

To change limits, edit the `min_capacity`, `max_capacity`, `task_cpu`, and `task_memory` values in the environment's `main.tf` and run `terraform apply`.

## Scaling Thresholds by User Count

### 1,000 Users (Current)
- 2 tasks @ 512 CPU / 1024 MB
- db.t3.medium (~400 max connections)
- Single NAT gateway

### 10,000 Users
- 4–8 tasks (auto-scaling handles this)
- Consider upgrading to db.t3.large or db.r6g.large
- Monitor RDS connection count alarm — add PgBouncer if connections become a bottleneck

### 50,000 Users
Tasks will auto-scale but you should proactively:
1. Increase `task_cpu` to 2048 and `task_memory` to 4096 in prod `main.tf`
2. Upgrade RDS to `db.r6g.large` (memory-optimized, better price/perf at this scale)
3. Enable RDS Performance Insights for query analysis (already enabled, 7-day retention)
4. Add a PgBouncer layer if connection count approaches the RDS limit

### 100,000 Users
1. Upgrade RDS to `db.r6g.xlarge` or `db.r6g.2xlarge`
2. Add a read replica for read-heavy workloads:
   ```hcl
   resource "aws_db_instance" "read_replica" {
     identifier             = "${var.project}-${var.environment}-replica"
     replicate_source_db    = aws_db_instance.main.identifier
     instance_class         = "db.r6g.large"
     publicly_accessible    = false
     vpc_security_group_ids = [var.rds_sg_id]
   }
   ```
3. Add PgBouncer as a sidecar or separate ECS service (connection pooling)
4. Consider CloudFront in front of the ALB for static content caching
5. Add ElastiCache Redis for session or frequently-read data caching

## RDS Connection Limits by Instance Class

| Class | Approx Max Connections |
|---|---|
| db.t3.micro | ~110 |
| db.t3.medium | ~400 |
| db.t3.large | ~800 |
| db.r6g.large | ~2,000 |
| db.r6g.xlarge | ~4,000 |

PostgreSQL's `max_connections` = `LEAST({DBInstanceClassMemory/9531392}, 5000)`.

The CloudWatch alarm triggers at 80% of `db_max_connections` (set per-environment in `main.tf`).

## Upgrading RDS Instance Class

RDS instance class changes cause a brief outage (~30s failover for Multi-AZ). Schedule during low-traffic windows or use the maintenance window.

```bash
# Change db_instance_class in terraform/environments/prod/main.tf, then:
terraform apply -var-file=terraform.tfvars -target=module.rds
```

With Multi-AZ enabled (prod), the failover is automatic and typically completes in under 60 seconds.

## Cost Estimates

| Environment | Monthly Est. |
|---|---|
| dev | ~$50–80 (single NAT, t3.micro RDS, FARGATE_SPOT) |
| staging | ~$200–300 (VPC endpoints, t3.medium RDS, 2 tasks) |
| prod (minimal) | ~$400–600 (3x NAT, t3.large Multi-AZ RDS, 2 tasks) |
| prod (10k users) | ~$600–1000 (4-8 tasks, r6g.large RDS) |

Major cost drivers: NAT gateways (~$32/each/month), RDS instance class, ECS task count.
