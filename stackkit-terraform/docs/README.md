# 📚 StackKit Terraform 문서

> 완전한 문서화로 모든 개발자가 쉽게 사용할 수 있는 Terraform 모듈 패키지

## 📋 문서 목록

### 🚀 시작하기

| 문서 | 대상 | 설명 |
|------|------|------|
| [MODULE_CATALOG.md](./MODULE_CATALOG.md) | 모든 사용자 | 전체 모듈 카탈로그 및 기능 설명 |
| [EXTERNAL_ADOPTION_GUIDE.md](./EXTERNAL_ADOPTION_GUIDE.md) | 외부 회사 | 외부 회사의 StackKit 도입 가이드 |
| [INFRASTRUCTURE_IMPORT_GUIDE.md](./INFRASTRUCTURE_IMPORT_GUIDE.md) | 기존 인프라 보유 팀 | 기존 AWS 인프라를 Terraform으로 가져오는 방법 |

### 👥 개발자 가이드

| 문서 | 대상 | 설명 |
|------|------|------|
| [INTERNAL_DEVELOPER_GUIDE.md](./INTERNAL_DEVELOPER_GUIDE.md) | 사내 개발자 | 사내 개발자를 위한 완전한 개발 워크플로우 |

## 🏗️ 모듈별 문서

### 💻 컴퓨팅 (Compute)
| 모듈 | 문서 위치 | 주요 기능 |
|------|-----------|----------|
| **EC2** | [modules/compute/ec2/README.md](../modules/compute/ec2/README.md) | EC2 인스턴스, 오토스케일링 그룹 |
| **ECS** | [modules/compute/ecs/README.md](../modules/compute/ecs/README.md) | ECS 클러스터, Fargate/EC2 서비스 |
| **Lambda** | [modules/compute/lambda/README.md](../modules/compute/lambda/README.md) | 서버리스 함수 |

### 🌐 네트워킹 (Networking)
| 모듈 | 문서 위치 | 주요 기능 |
|------|-----------|----------|
| **VPC** | [modules/networking/vpc/README.md](../modules/networking/vpc/README.md) | VPC, 서브넷, 라우팅 |
| **ALB** | [modules/networking/alb/README.md](../modules/networking/alb/README.md) | Application Load Balancer |
| **CloudFront** | [modules/networking/cloudfront/README.md](../modules/networking/cloudfront/README.md) | CDN 배포 |
| **Route53** | [modules/networking/route53/README.md](../modules/networking/route53/README.md) | DNS 관리 |

### 🗄️ 데이터베이스 (Database)
| 모듈 | 문서 위치 | 주요 기능 |
|------|-----------|----------|
| **RDS** | [modules/database/rds/README.md](../modules/database/rds/README.md) | 관계형 데이터베이스 |
| **DynamoDB** | [modules/database/dynamodb/README.md](../modules/database/dynamodb/README.md) | NoSQL 데이터베이스 |
| **ElastiCache** | [modules/database/elasticache/README.md](../modules/database/elasticache/README.md) | Redis/Memcached 캐시 |

### 💾 스토리지 (Storage)
| 모듈 | 문서 위치 | 주요 기능 |
|------|-----------|----------|
| **S3** | [modules/storage/s3/README.md](../modules/storage/s3/README.md) | 객체 스토리지 |

### 🔐 보안 (Security)
| 모듈 | 문서 위치 | 주요 기능 |
|------|-----------|----------|
| **IAM** | [modules/security/iam/README.md](../modules/security/iam/README.md) | 역할 및 정책 관리 |
| **KMS** | [modules/security/kms/README.md](../modules/security/kms/README.md) | 암호화 키 관리 |
| **Secrets Manager** | [modules/security/secrets-manager/README.md](../modules/security/secrets-manager/README.md) | 시크릿 관리 |

### 📊 모니터링 (Monitoring)
| 모듈 | 문서 위치 | 주요 기능 |
|------|-----------|----------|
| **CloudWatch** | [modules/monitoring/cloudwatch/README.md](../modules/monitoring/cloudwatch/README.md) | 메트릭, 알람, 대시보드 |
| **SNS** | [modules/monitoring/sns/README.md](../modules/monitoring/sns/README.md) | 알림 서비스 |
| **EventBridge** | [modules/monitoring/eventbridge/README.md](../modules/monitoring/eventbridge/README.md) | 이벤트 버스 |

### 🔄 통합 (Integration)
| 모듈 | 문서 위치 | 주요 기능 |
|------|-----------|----------|
| **SQS** | [modules/integration/sqs/README.md](../modules/integration/sqs/README.md) | 메시지 큐 |

## 🎯 사용 시나리오별 가이드

### 🆕 새로운 회사에서 StackKit 도입
1. **[EXTERNAL_ADOPTION_GUIDE.md](./EXTERNAL_ADOPTION_GUIDE.md)** 읽기
2. **[MODULE_CATALOG.md](./MODULE_CATALOG.md)**에서 필요한 모듈 확인
3. 각 모듈의 README에서 상세 사용법 확인

### 🏢 기존 인프라를 Terraform으로 관리하고 싶은 경우
1. **[INFRASTRUCTURE_IMPORT_GUIDE.md](./INFRASTRUCTURE_IMPORT_GUIDE.md)** 읽기
2. 모듈별 import 섹션 확인
3. 단계별 import 실행

### 👨‍💻 사내 개발자로서 기여하고 싶은 경우
1. **[INTERNAL_DEVELOPER_GUIDE.md](./INTERNAL_DEVELOPER_GUIDE.md)** 읽기
2. 개발 워크플로우 따르기
3. 코드 리뷰 가이드라인 준수

### 🔧 특정 모듈 사용법을 알고 싶은 경우
1. **[MODULE_CATALOG.md](./MODULE_CATALOG.md)**에서 모듈 개요 확인
2. 해당 모듈의 README.md에서 상세 정보 확인
3. 예제 코드로 실습

## 📖 빠른 참조

### 자주 찾는 정보

| 질문 | 답변 위치 |
|------|-----------|
| **어떤 모듈이 있나요?** | [MODULE_CATALOG.md](./MODULE_CATALOG.md) |
| **VPC는 어떻게 만드나요?** | [modules/networking/vpc/README.md](../modules/networking/vpc/README.md) |
| **기존 RDS를 가져오려면?** | [INFRASTRUCTURE_IMPORT_GUIDE.md](./INFRASTRUCTURE_IMPORT_GUIDE.md) |
| **새 모듈을 만들려면?** | [INTERNAL_DEVELOPER_GUIDE.md](./INTERNAL_DEVELOPER_GUIDE.md) |
| **다른 회사에서 사용하려면?** | [EXTERNAL_ADOPTION_GUIDE.md](./EXTERNAL_ADOPTION_GUIDE.md) |

### 응급 상황 가이드

| 상황 | 해결책 |
|------|-------|
| **Import 실패** | [INFRASTRUCTURE_IMPORT_GUIDE.md](./INFRASTRUCTURE_IMPORT_GUIDE.md#common-challenges) |
| **State Lock 문제** | [INTERNAL_DEVELOPER_GUIDE.md](./INTERNAL_DEVELOPER_GUIDE.md#troubleshooting) |
| **Permission 에러** | [EXTERNAL_ADOPTION_GUIDE.md](./EXTERNAL_ADOPTION_GUIDE.md#prerequisites) |
| **모듈 에러** | 각 모듈의 README.md Troubleshooting 섹션 |


