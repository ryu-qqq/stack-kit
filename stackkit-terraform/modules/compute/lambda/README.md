# Lambda 모듈

AWS Lambda 함수를 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- Lambda 함수 생성
- IAM 역할 및 정책 자동 생성
- VPC 연결 지원
- 환경 변수 관리
- CloudWatch Logs 연동
- API Gateway 트리거 지원

## 사용법

```hcl
module "api_function" {
  source = "../../modules/lambda"
  
  project_name  = "my-app"
  environment   = "dev"
  function_name = "api-handler"
  
  runtime = "python3.11"
  handler = "app.lambda_handler"
  filename = "api-handler.zip"
  
  memory_size = 128
  timeout     = 30
  
  environment_variables = {
    DB_ENDPOINT = module.database.endpoint
    LOG_LEVEL   = "INFO"
  }
  
  common_tags = local.common_tags
}
```