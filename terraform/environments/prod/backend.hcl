bucket         = "myapp-terraform-state-REPLACE_WITH_ACCOUNT_ID"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "myapp-terraform-locks"
encrypt        = true
