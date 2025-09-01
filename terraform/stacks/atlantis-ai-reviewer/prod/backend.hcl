bucket         = "connectly-prod"
key            = "terraform/prod/atlantis/terraform.tfstate"
region         = "ap-northeast-2"
dynamodb_table = "prod-connectly-tf-lock"
encrypt        = true
