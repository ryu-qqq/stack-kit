package com.stackkit.plan.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.stackkit.plan.model.Models.Manifest;
import com.stackkit.plan.model.Models.PolicyFinding;
import com.stackkit.plan.model.Models.PolicyReport;
import com.stackkit.plan.util.Common;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 입력: { bucket, prefix, tfplanKey, planTxtKey, applyTxtKey, manifest:{...}, (옵션)adds/mods/dels/byType, (옵션)policyReport }
 * 환경: SLACK_WEBHOOK_URL, PRESIGN_TTL_SECONDS(기본 3600)
 */
public class SlackNotifierHandler implements RequestHandler<Map<String,Object>, Map<String,Object>> {
    @Override
    public Map<String, Object> handleRequest(Map<String, Object> input, Context context) {
        String bucket = (String) input.get("bucket");
        String planTxtKey = (String) input.get("planTxtKey");
        String tfplanKey  = (String) input.get("tfplanKey");
        Map<String,Object> manifestMap = (Map<String, Object>) input.get("manifest");
        Manifest man = Common.M.convertValue(manifestMap, Manifest.class);

        String webhook = Optional.ofNullable(System.getenv("SLACK_WEBHOOK_URL"))
            .orElseThrow(() -> new IllegalArgumentException("SLACK_WEBHOOK_URL required"));
        long ttl = Optional.ofNullable(System.getenv("PRESIGN_TTL_SECONDS")).map(Long::parseLong).orElse(3600L);

        try (S3Presigner presigner = Common.presigner()) {
            String planTxtUrl = Common.presign(presigner, bucket, planTxtKey, ttl);
            String tfplanUrl  = Common.presign(presigner, bucket, tfplanKey, ttl);
            String applyTxtKey = (String) input.get("applyTxtKey");
            String applyTxtUrl = (applyTxtKey != null)? Common.presign(presigner, bucket, applyTxtKey, ttl) : null;

            // 위험 보고서(옵션)
            PolicyReport pr = null;
            if (input.containsKey("policyReport")) {
                pr = Common.M.convertValue(input.get("policyReport"), PolicyReport.class);
            }

            String heading = "*Terraform " + man.action() + "* — " + man.repo() + " #" + man.pr() + " (" + man.project() + ")";
            StringBuilder msg = new StringBuilder();
            msg.append(heading).append("\n");

            if ("apply".equalsIgnoreCase(man.action())) {
                String statusEmoji = "success".equalsIgnoreCase(man.status()) ? "✅ 성공" : "❌ 실패";
                msg.append("- 결과: ").append(statusEmoji).append("\n");
                if (applyTxtUrl != null) {
                    msg.append("- apply 로그: <").append(applyTxtUrl).append("|apply.txt>\n");
                }
                msg.append("- plan: <").append(tfplanUrl).append("|json> · <").append(planTxtUrl).append("|txt>\n");
            } else {
                int adds = ((Number) input.getOrDefault("adds", 0)).intValue();
                int mods = ((Number) input.getOrDefault("mods", 0)).intValue();
                int dels = ((Number) input.getOrDefault("dels", 0)).intValue();
                String hasChanges = man.has_changes()!=null && man.has_changes() ? "변경 있음" : "변경 없음";
                msg.append("- 변경 감지: ").append(hasChanges).append("\n");
                msg.append(String.format("- 추가:%d 변경:%d 삭제:%d%n", adds, mods, dels));
                msg.append("- plan: <").append(tfplanUrl).append("|json> · <").append(planTxtUrl).append("|txt>\n");
            }

            if (pr != null) {
                msg.append(String.format("- 위험도: HIGH:%d MEDIUM:%d INFO:%d%n", pr.high, pr.medium, pr.info));
                // 상위 몇 개만 노출(과다 스팸 방지)
                List<PolicyFinding> list = pr.findings;
                int limit = Math.min(list.size(), 5);
                for (int i=0;i<limit;i++) {
                    PolicyFinding f = list.get(i);
                    msg.append(String.format("  • [%s] %s — %s%n", f.severity, f.code, f.message));
                }
                if (list.size() > limit) {
                    msg.append(String.format("  • ...외 %d건", (list.size()-limit))).append("\n");
                }
            }

            Common.sendSlack(webhook, msg.toString());
            return input;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
