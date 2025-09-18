terraform {
  backend "s3" {
    bucket         = "prod-ORG_NAME_PLACEHOLDER"
    key            = "atlantis/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-ORG_NAME_PLACEHOLDER-tf-lock"
    encrypt        = true
  }
}
