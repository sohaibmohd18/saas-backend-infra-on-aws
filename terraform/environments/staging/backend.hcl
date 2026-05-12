bucket         = "myapp-terraform-state-REPLACE_WITH_ACCOUNT_ID"
key            = "staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "myapp-terraform-locks"
encrypt        = true
