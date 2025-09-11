package terraform

# ===== 설정 =====
required_tags := ["Environment", "Project", "Component", "ManagedBy"]
valid_environments := {"dev", "prod"}  # 팀 기준

# ===== 입력 헬퍼 =====
plan := input
rcs := plan.resource_changes
config := plan.configuration

# after(계획 적용 후) 값 가져오기
after(rc) := v {
  some i
  rc.change.after != null
  v := rc.change.after
}

# 자원 타입/액션 필터
is_managed_resource(rc) {
  rc.type != ""
  rc.mode == "managed"
}
will_be_applied(rc) {
  some a
  a := rc.change.actions[_]
  a == "create" or a == "update" or a == "replace"
}

# 태그 맵 추출 (tags_all 우선)
tags(rc) := t {
  after(rc).tags_all != null
  t := after(rc).tags_all
} else := t {
  after(rc).tags != null
  t := after(rc).tags
} else := t {
  t := {}
}

# 보안그룹/룰의 0.0.0.0/0 탐지
cidrs_after(rc) := s {
  t := rc.type
  v := after(rc)
  some cidr
  (t == "aws_security_group"  and v.ingress[_].cidr_blocks[_] == cidr)  or
  (t == "aws_security_group"  and v.egress[_].cidr_blocks[_]  == cidr) or
  (t == "aws_security_group_rule" and v.cidr_blocks[_] == cidr)
  s := cidr
}

is_public_cidr(c) { c == "0.0.0.0/0" }

# 예외: 태그로 허용 (AllowPublicExempt=true) 또는 설명에 ALLOW_PUBLIC_EXEMPT 포함
is_public_exempt(rc) {
  t := tags(rc)
  lower(t["AllowPublicExempt"]) == "true"  # 표준 태그
} else {
  v := after(rc)
  contains(lower(v.description), "allow_public_exempt")
}

# ===== 규칙: 데이터소스 이름 조회 금지(SQS/SNS) =====
deny[msg] {
  some r
  r := config.root_module.resources[_]
  r.mode == "data"
  startswith(r.type, "aws_sqs_queue")  # data "aws_sqs_queue"
  msg := sprintf("Do not use data.aws_sqs_queue: %v", [r.name])
}
deny[msg] {
  some r
  r := config.root_module.resources[_]
  r.mode == "data"
  startswith(r.type, "aws_sns_topic")
  msg := sprintf("Do not use data.aws_sns_topic: %v", [r.name])
}

# ===== 규칙: 필수 태그 =====
deny[msg] {
  rc := rcs[_]
  is_managed_resource(rc)
  will_be_applied(rc)
  t := tags(rc)
  some k
  k := required_tags[_]
  not t[k]
  msg := sprintf("Missing required tag '%s' on %s.%s", [k, rc.type, rc.name])
}

# ===== 규칙: Environment 태그 값 검증 =====
deny[msg] {
  rc := rcs[_]
  is_managed_resource(rc)
  will_be_applied(rc)
  t := tags(rc)
  not t["Environment"]
  msg := sprintf("Tag 'Environment' is required on %s.%s", [rc.type, rc.name])
}
deny[msg] {
  rc := rcs[_]
  is_managed_resource(rc)
  will_be_applied(rc)
  t := tags(rc)
  env := lower(t["Environment"])
  not valid_environments[env]
  msg := sprintf("Invalid Environment tag '%s' on %s.%s (allowed: %v)", [t["Environment"], rc.type, rc.name, valid_environments])
}

# ===== 규칙: SG 공개 차단(예외 허용) =====
deny[msg] {
  rc := rcs[_]
  will_be_applied(rc)
  some c
  c := cidrs_after(rc)
  is_public_cidr(c)
  not is_public_exempt(rc)
  msg := sprintf("Public CIDR 0.0.0.0/0 not allowed on %s.%s", [rc.type, rc.name])
}

# ===== 경고: 태그 부족하지만 데이터 리소스/특정 타입 제외 시 완화 가능 =====
warn[msg] {
  rc := rcs[_]
  is_managed_resource(rc)
  will_be_applied(rc)
  t := tags(rc)
  count({k | k := required_tags[_]; t[k]}) < count(required_tags)
  msg := sprintf("Tag coverage incomplete on %s.%s (have: %v)", [rc.type, rc.name, {k: t[k] | k := required_tags[_]; t[k]}])
}
