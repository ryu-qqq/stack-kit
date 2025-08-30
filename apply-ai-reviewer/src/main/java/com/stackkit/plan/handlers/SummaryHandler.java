package com.stackkit.plan.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.core.type.TypeReference;
import com.stackkit.plan.model.Models.Summary;
import com.stackkit.plan.model.Models.TypeSummary;
import com.stackkit.plan.util.Common;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.util.*;

/** 입력: { "bucket":"...", "tfplanKey":".../tfplan.json", "prefix":"..."}  */
public class SummaryHandler implements RequestHandler<Map<String,Object>, Map<String,Object>> {
    @Override
    public Map<String, Object> handleRequest(Map<String, Object> input, Context context) {
        String bucket = (String) input.get("bucket");
        String tfplanKey = (String) input.get("tfplanKey");
        String prefix = (String) input.get("prefix");
        String ddbTable = System.getenv("IDEMPOTENCY_TABLE"); // optional

        try (S3Client s3 = Common.s3()) {
            // 멱등성: S3 VersionId or ETag 기반
            var head = Common.head(s3, bucket, tfplanKey);
            String version = Optional.ofNullable(head.versionId()).orElse(head.eTag());
            boolean shouldProcess = true;
            if (ddbTable != null && !ddbTable.isBlank()) {
                try (DynamoDbClient ddb = Common.ddb()) {
                    shouldProcess = Common.idempotentPut(ddb, ddbTable, bucket + "#" + tfplanKey + "#" + version, Map.of());
                }
            }
            if (!shouldProcess) {
                return Map.of("skipped", true, "reason", "already-processed");
            }

            byte[] tfplanBytes = Common.getBytes(s3, bucket, tfplanKey);
            Map<String,Object> plan = Common.M.readValue(tfplanBytes, new TypeReference<Map<String,Object>>() {});
            List<Map<String,Object>> rcs = (List<Map<String,Object>>) plan.getOrDefault("resource_changes", List.of());

            int adds=0, mods=0, dels=0;
            Map<String,int[]> byType = new HashMap<>();
            for (var rc : rcs) {
                String type = (String) rc.get("type");
                Map<String,Object> change = (Map<String,Object>) rc.get("change");
                List<String> actions = (List<String>) change.get("actions");
                int[] cud = byType.computeIfAbsent(type, t -> new int[]{0,0,0});
                for (String a : actions) switch (a) {
                    case "create" -> { adds++; cud[0]++; }
                    case "update" -> { mods++; cud[1]++; }
                    case "delete" -> { dels++; cud[2]++; }
                }
            }

            List<TypeSummary> top = new ArrayList<>();
            for (var e : byType.entrySet()) {
                top.add(new TypeSummary(e.getKey(), e.getValue()[0], e.getValue()[1], e.getValue()[2]));
            }
            top.sort(Comparator.comparingInt(TypeSummary::total).reversed());
            if (top.size()>10) top = top.subList(0,10);

            Summary s = new Summary(adds, mods, dels, top, bucket, tfplanKey);
            String summaryKey = prefix + "/summary.json";
            s3.putObject(PutObjectRequest.builder()
                    .bucket(bucket).key(summaryKey).contentType("application/json").build(),
                RequestBody.fromBytes(Common.M.writeValueAsBytes(s)));

            Map<String,Object> out = new HashMap<>(input);
            out.put("summaryKey", summaryKey);
            out.put("adds", adds); out.put("mods", mods); out.put("dels", dels);
            out.put("byType", top);
            return out;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
