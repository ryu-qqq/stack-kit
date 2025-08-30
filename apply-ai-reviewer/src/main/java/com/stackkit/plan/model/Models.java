package com.stackkit.plan.model;

import java.util.List;
import java.util.Map;

public class Models {
    // atlantis가 업로드한 manifest.json 구조(예시)
    public record Manifest(
        String repo,          // "owner/name"
        int    pr,            // PR 번호
        String project,       // atlantis project
        String action,        // "plan" | "apply"
        String status,        // "success" | "failure" (apply)
        String commit,        // git sha
        Boolean has_changes   // plan에서 변경 존재 여부
    ) {}

    public static class TypeSummary {
        public String type; public int create, update, delete;
        public TypeSummary() {}
        public TypeSummary(String type, int c, int u, int d) { this.type=type; this.create=c; this.update=u; this.delete=d; }
        public int total() { return create + update + delete; }
    }

    public static class Summary {
        public int adds, mods, dels;
        public List<TypeSummary> byType;
        public Map<String,String> s3;
        public Summary() {}
        public Summary(int a, int m, int d, List<TypeSummary> byType, String bucket, String key) {
            this.adds=a; this.mods=m; this.dels=d; this.byType=byType;
            this.s3 = Map.of("bucket", bucket, "key", key);
        }
    }

    public static class PolicyFinding {
        public String severity;  // HIGH | MEDIUM | INFO
        public String code;      // 예: SG_OPEN_INGRESS
        public String message;   // 사람이 읽을 수 있는 설명
        public String resource;  // 리소스 주소(type.name or addr)
        public PolicyFinding() {}
        public PolicyFinding(String severity, String code, String message, String resource) {
            this.severity=severity; this.code=code; this.message=message; this.resource=resource;
        }
    }

    public static class PolicyReport {
        public int high; public int medium; public int info;
        public List<PolicyFinding> findings;
        public PolicyReport() {}
        public PolicyReport(int h, int m, int i, List<PolicyFinding> f) { high=h; medium=m; info=i; findings=f; }
    }
}
