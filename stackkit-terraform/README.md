# StackKit Terraform Modules

> 기본 인프라 구성을 위한 저수준 Terraform 모듈 라이브러리

## 📁 구조

```
stackkit-terraform/
├── modules/           # 재사용 가능한 Terraform 모듈
│   ├── networking/    # VPC, ALB, CloudFront, Route53 등
│   ├── compute/       # EC2, EKS, Auto Scaling
│   ├── security/      # IAM, KMS, Secrets Manager, WAF
│   ├── storage/       # EFS, Backup
│   ├── monitoring/    # CloudTrail, EventBridge
│   └── enterprise/    # 팀 경계, 컴플라이언스
├── policies/          # OPA/Sentinel 정책 (선택적)
└── README.md         # 이 문서
```

## 🎯 모듈 vs 애드온

### stackkit-terraform/modules (저수준)
- **목적**: 기본 AWS 리소스 정의
- **사용자**: 인프라 전문가
- **특징**: 세밀한 제어, 높은 유연성

### addons (고수준)
- **목적**: 즉시 사용 가능한 서비스 패턴
- **사용자**: 일반 개발자
- **특징**: 환경별 설정, 모니터링 포함, 빠른 시작

## 📦 핵심 모듈

### Networking
- `vpc` - VPC 및 서브넷 구성
- `alb` - Application Load Balancer
- `nlb` - Network Load Balancer
- `cloudfront` - CDN 구성
- `route53` - DNS 관리
- `api-gateway` - API Gateway
- `transit-gateway` - 멀티 VPC 연결

### Compute
- `ec2` - EC2 인스턴스
- `eks` - Kubernetes 클러스터
- `autoscaling` - Auto Scaling Groups

### Security
- `iam` - IAM 역할 및 정책
- `kms` - 암호화 키 관리
- `secrets-manager` - 시크릿 관리
- `acm` - SSL/TLS 인증서
- `waf` - Web Application Firewall
- `guardduty` - 위협 탐지

### Storage
- `efs` - Elastic File System
- `backup` - AWS Backup

### Monitoring
- `cloudtrail` - 감사 로깅
- `eventbridge` - 이벤트 버스

### Enterprise
- `team-boundaries` - 팀별 경계 설정
- `compliance` - 규정 준수 자동화
- `multi-account` - 다중 계정 관리

## 🚀 사용 방법

### 직접 모듈 사용
```hcl
module "vpc" {
  source = "git::https://github.com/company/stackkit-terraform.git//modules/networking/vpc?ref=v1.0.0"
  
  cidr_block = "10.0.0.0/16"
  environment = "production"
}
```

### 애드온에서 참조
```hcl
# addons/compute/ecs/main.tf
module "alb" {
  source = "../../stackkit-terraform/modules/networking/alb"
  # ...
}
```

## 🔄 버전 관리

모든 모듈은 시맨틱 버저닝을 따릅니다:
- `v1.0.0` - 프로덕션 준비 완료
- `v0.x.x` - 개발 중

## 📝 기여 가이드

1. 모듈은 단일 책임 원칙을 따라야 함
2. 모든 변수에 설명과 타입 정의 필수
3. outputs는 다른 모듈에서 참조 가능하도록 설계
4. 각 모듈마다 README.md 포함

## 🔗 관련 문서

- [Addons 시스템](../addons/README.md)
- [Templates](../templates/README.md)
- [StackKit CLI](../tools/stackkit-cli.sh)