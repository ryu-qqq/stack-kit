package com.stackkit.plan.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.core.type.TypeReference;
import com.stackkit.plan.model.Models.PolicyFinding;
import com.stackkit.plan.model.Models.PolicyReport;
import com.stackkit.plan.util.Common;
import software.amazon.awssdk.services.s3.S3Client;

import java.util.*;

/**
 * 간단한 규칙 기반 위험 탐지(정형) — tfplan.json의 "resource_changes[*].change.after"를 살핍니다.
 * 입력: { bucket, tfplanKey, ... }
 * 출력: 입력 + { policyReport: { high, medium, info, findings:[...] } }
 */
public class PolicyEvalHandler implements RequestHandler<Map<String,Object>, Map<String,Object>> {
    @Override
    public Map<String, Object> handleRequest(Map<String, Object> input, Context context) {
        String bucket = (String) input.get("bucket");
        String tfplanKey = (String) input.get("tfplanKey");

        try (S3Client s3 = Common.s3()) {
            byte[] tfplanBytes = Common.getBytes(s3, bucket, tfplanKey);
            Map<String,Object> plan = Common.M.readValue(tfplanBytes, new TypeReference<Map<String,Object>>() {});
            List<Map<String,Object>> rcs = (List<Map<String,Object>>) plan.getOrDefault("resource_changes", List.of());

            List<PolicyFinding> findings = new ArrayList<>();

            for (var rc : rcs) {
                String type = (String) rc.get("type");
                String addr = (String) rc.getOrDefault("address", type);
                Map<String,Object> change = (Map<String,Object>) rc.get("change");
                Map<String,Object> after = change == null ? null : (Map<String,Object>) change.get("after");
                if (after == null) continue;

                // 1) Security Group: 0.0.0.0/0 위험
                if ("aws_security_group".equals(type) || "aws_security_group_rule".equals(type)) {
                    List<Map<String,Object>> ingress = listMap(after.get("ingress"));
                    for (var in : ingress) {
                        if (cidrAny(in.get("cidr_blocks")) || cidrAny(in.get("ipv6_cidr_blocks"))) {
                            Integer from = toInt(in.get("from_port"));
                            Integer to   = toInt(in.get("to_port"));
                            String proto = String.valueOf(in.get("protocol"));
                            String msg = "Security Group ingress open to world: " + range(from,to) + " proto=" + proto;
                            findings.add(new PolicyFinding("HIGH","SG_OPEN_INGRESS", msg, addr));
                        }
                    }
                }

                // 2) S3 퍼블릭 가능성
                if ("aws_s3_bucket".equals(type)) {
                    // 단순 추정: ACL이 public-read/public-read-write면 위험
                    String acl = str(after.get("acl"));
                    if ("public-read".equalsIgnoreCase(acl) || "public-read-write".equalsIgnoreCase(acl)) {
                        findings.add(new PolicyFinding("HIGH","S3_PUBLIC_ACL", "S3 bucket ACL is public", addr));
                    }
                }
                if ("aws_s3_bucket_public_access_block".equals(type)) {
                    Boolean blockAll = asBool(after.get("block_public_acls")) && asBool(after.get("block_public_policy"))
                        && asBool(after.get("ignore_public_acls")) && asBool(after.get("restrict_public_buckets"));
                    if (!blockAll) {
                        findings.add(new PolicyFinding("MEDIUM","S3_PAB_DISABLED", "Public access block not fully enabled", addr));
                    }
                }

                // 3) RDS Publicly Accessible
                if ("aws_db_instance".equals(type)) {
                    if (Boolean.TRUE.equals(after.get("publicly_accessible"))) {
                        findings.add(new PolicyFinding("HIGH","RDS_PUBLIC", "RDS instance publicly_accessible=true", addr));
                    }
                }

                // 4) IAM Policy 와일드카드
                if ("aws_iam_policy".equals(type) || "aws_iam_role_policy".equals(type) || "aws_iam_role_policy_attachment".equals(type)) {
                    // after.document(JSON string) 또는 policy JSON 추정
                    Object pol = after.get("policy");
                    if (pol instanceof String s && s.contains("*")) {
                        findings.add(new PolicyFinding("MEDIUM","IAM_WILDCARD", "IAM policy may contain wildcards", addr));
                    }
                }
            }

            int h=0,m=0,i=0;
            for (var f : findings) {
                switch (f.severity) {
                    case "HIGH" -> h++;
                    case "MEDIUM" -> m++;
                    default -> i++;
                }
            }
            PolicyReport report = new PolicyReport(h,m,i,findings);

            Map<String,Object> out = new HashMap<>(input);
            out.put("policyReport", report);
            return out;

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    // ------- 유틸(간단) -------
    private static List<Map<String,Object>> listMap(Object v) {
        if (v instanceof List<?> l) {
            List<Map<String,Object>> out = new ArrayList<>();
            for (var e : l) if (e instanceof Map<?,?> m) out.add((Map<String,Object>) m);
            return out;
        }
        return List.of();
    }

    private static boolean cidrAny(Object v) {
        if (v instanceof List<?> l) {
            for (var e : l) if (e != null && "0.0.0.0/0".equals(String.valueOf(e)) || "::/0".equals(String.valueOf(e))) return true;
        }
        return false;
    }

    private static Integer toInt(Object v) {
        if (v instanceof Number n) return n.intValue();
        try { return v==null? null : Integer.parseInt(String.valueOf(v)); } catch (Exception e) { return null; }
    }

    private static String range(Integer from, Integer to) {
        if (from==null && to==null) return "ALL";
        if (from!=null && to!=null && from.equals(to)) return String.valueOf(from);
        return (from==null? "*" : from) + "-" + (to==null? "*" : to);
    }

    private static String str(Object v) { return v==null? null : String.valueOf(v); }
    private static boolean asBool(Object v) {
        if (v instanceof Boolean b) return b;
        if (v==null) return false;
        return "true".equalsIgnoreCase(String.valueOf(v));
    }
}
