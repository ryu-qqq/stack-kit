package com.stackkit.plan.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.stackkit.plan.model.Models.Manifest;
import com.stackkit.plan.util.Common;
import software.amazon.awssdk.services.s3.S3Client;

import java.util.HashMap;
import java.util.Map;

/**
 * 입력: { "bucket":"...", "key":".../manifest.json" } 또는 EventBridge S3 Put detail
 * 출력: { bucket, prefix, manifest:{...}, tfplanKey, planTxtKey, applyTxtKey }
 * 핸들러: com.stackkit.plan.handlers.ManifestRouterHandler::handleRequest
 */
public class ManifestRouterHandler implements RequestHandler<Map<String,Object>, Map<String,Object>> {
    @Override
    public Map<String, Object> handleRequest(Map<String, Object> input, Context context) {
        try (S3Client s3 = Common.s3()) {
            var ptr = extractS3(input);
            byte[] bytes = Common.getBytes(s3, ptr.bucket, ptr.key);
            Manifest man = Common.M.readValue(bytes, Manifest.class);

            String prefix = ptr.key.substring(0, ptr.key.lastIndexOf('/'));

            Map<String,Object> out = new HashMap<>();
            out.put("bucket", ptr.bucket);
            out.put("prefix", prefix);
            out.put("manifest", man);
            out.put("tfplanKey", prefix + "/tfplan.json");
            out.put("planTxtKey", prefix + "/plan.txt");
            out.put("applyTxtKey", prefix + "/apply.txt"); // 있을 수도, 없을 수도
            return out;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    record S3Ptr(String bucket, String key) {}

    private S3Ptr extractS3(Map<String,Object> input) {
        // 직접 {bucket,key} 형태
        if (input.containsKey("bucket") && input.containsKey("key")) {
            return new S3Ptr((String)input.get("bucket"), (String)input.get("key"));
        }
        // EventBridge S3 PutObject detail
        Map<String,Object> detail = (Map<String,Object>) input.get("detail");
        if (detail != null) {
            Map<String,Object> b = (Map<String,Object>) detail.get("bucket");
            Map<String,Object> o = (Map<String,Object>) detail.get("object");
            if (b != null && o != null) {
                return new S3Ptr((String)b.get("name"), (String)o.get("key"));
            }
        }
        throw new IllegalArgumentException("Unsupported input: expect {bucket,key} or EventBridge detail");
    }
}
