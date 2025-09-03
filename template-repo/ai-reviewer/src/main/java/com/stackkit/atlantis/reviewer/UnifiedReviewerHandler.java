package com.stackkit.atlantis.reviewer;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;

/**
 * Unified AWS Lambda handler for AI-powered Terraform plan and apply reviews
 * Processes SQS messages and determines whether to handle as plan review or apply completion
 * Uses FIFO queue with message attributes for proper routing
 */
public class UnifiedReviewerHandler implements RequestHandler<SQSEvent, String> {
    
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final HttpClient HTTP_CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(30))
            .build();
    
    // Message types for routing
    private enum MessageType {
        PLAN_REVIEW,
        APPLY_COMPLETION,
        UNKNOWN
    }
    
    private final S3Client s3Client;
    private final String bucketName;
    private final String slackWebhookUrl;
    private final String openaiApiKey;
    private final String infracostApiKey;
    
    public UnifiedReviewerHandler() {
        this.s3Client = S3Client.create();
        this.bucketName = System.getenv("S3_BUCKET");
        this.slackWebhookUrl = System.getenv("SLACK_WEBHOOK_URL");
        this.openaiApiKey = System.getenv("OPENAI_API_KEY");
        this.infracostApiKey = System.getenv("INFRACOST_API_KEY");
    }
    
    @Override
    public String handleRequest(SQSEvent event, Context context) {
        context.getLogger().log("Processing " + event.getRecords().size() + " SQS records in unified handler");
        
        int planReviews = 0;
        int applyCompletions = 0;
        int errors = 0;
        
        for (SQSEvent.SQSMessage message : event.getRecords()) {
            try {
                MessageType messageType = determineMessageType(message, context);
                
                switch (messageType) {
                    case PLAN_REVIEW:
                        processPlanReview(message, context);
                        planReviews++;
                        break;
                    case APPLY_COMPLETION:
                        processApplyCompletion(message, context);
                        applyCompletions++;
                        break;
                    case UNKNOWN:
                        context.getLogger().log("Unknown message type for message: " + message.getMessageId());
                        errors++;
                        break;
                }
            } catch (Exception e) {
                context.getLogger().log("Error processing message " + message.getMessageId() + ": " + e.getMessage());
                errors++;
            }
        }
        
        String result = String.format("Processed: %d plan reviews, %d apply completions, %d errors", 
                                    planReviews, applyCompletions, errors);
        context.getLogger().log(result);
        return result;
    }
    
    private MessageType determineMessageType(SQSEvent.SQSMessage message, Context context) {
        try {
            // Method 1: Check message attributes first (preferred)
            Map<String, SQSEvent.MessageAttribute> attributes = message.getMessageAttributes();
            if (attributes != null && attributes.containsKey("MessageType")) {
                String messageType = attributes.get("MessageType").getStringValue();
                if ("PLAN_REVIEW".equals(messageType)) {
                    return MessageType.PLAN_REVIEW;
                } else if ("APPLY_COMPLETION".equals(messageType)) {
                    return MessageType.APPLY_COMPLETION;
                }
            }
            
            // Method 2: Check message group ID for FIFO queue
            String messageGroupId = message.getAttributes().get("MessageGroupId");
            if (messageGroupId != null) {
                if (messageGroupId.contains("plan")) {
                    return MessageType.PLAN_REVIEW;
                } else if (messageGroupId.contains("apply")) {
                    return MessageType.APPLY_COMPLETION;
                }
            }
            
            // Method 3: Analyze S3 object key pattern from message body
            JsonNode messageBody = MAPPER.readTree(message.getBody());
            
            // Handle direct S3 event notifications
            if (messageBody.has("Records")) {
                JsonNode records = messageBody.get("Records");
                if (records.isArray() && records.size() > 0) {
                    for (JsonNode record : records) {
                        if (record.has("s3")) {
                            String objectKey = record.get("s3").get("object").get("key").asText();
                            return classifyByObjectKey(objectKey);
                        }
                    }
                }
            }
            
            // Handle custom message format
            if (messageBody.has("objectKey")) {
                String objectKey = messageBody.get("objectKey").asText();
                return classifyByObjectKey(objectKey);
            }
            
            if (messageBody.has("eventType")) {
                String eventType = messageBody.get("eventType").asText();
                if ("plan_created".equals(eventType)) {
                    return MessageType.PLAN_REVIEW;
                } else if ("apply_completed".equals(eventType)) {
                    return MessageType.APPLY_COMPLETION;
                }
            }
            
        } catch (Exception e) {
            context.getLogger().log("Error determining message type: " + e.getMessage());
        }
        
        return MessageType.UNKNOWN;
    }
    
    private MessageType classifyByObjectKey(String objectKey) {
        // Classify based on S3 object key patterns
        if (objectKey.contains("/plans/") || objectKey.endsWith(".tfplan") || objectKey.contains("plan-")) {
            return MessageType.PLAN_REVIEW;
        } else if (objectKey.contains("/applies/") || objectKey.contains("/outputs/") || 
                   objectKey.endsWith(".apply") || objectKey.contains("apply-")) {
            return MessageType.APPLY_COMPLETION;
        }
        
        return MessageType.UNKNOWN;
    }
    
    private void processPlanReview(SQSEvent.SQSMessage message, Context context) throws Exception {
        context.getLogger().log("Processing plan review for message: " + message.getMessageId());
        
        // Parse S3 event from SQS message
        JsonNode messageBody = MAPPER.readTree(message.getBody());
        String objectKey = extractObjectKey(messageBody);
        
        if (objectKey == null) {
            context.getLogger().log("No object key found in plan review message");
            return;
        }
        
        context.getLogger().log("Processing plan file: " + objectKey);
        
        // Download and analyze the plan file
        String planContent = downloadS3Object(objectKey);
        TerraformPlanAnalysis analysis = analyzePlan(planContent, context);
        
        // Generate AI review
        String aiReview = generatePlanAIReview(analysis, context);
        
        // Send to Slack
        sendPlanReviewNotification(analysis, aiReview, objectKey, context);
    }
    
    private void processApplyCompletion(SQSEvent.SQSMessage message, Context context) throws Exception {
        context.getLogger().log("Processing apply completion for message: " + message.getMessageId());
        
        // Parse message body
        JsonNode messageBody = MAPPER.readTree(message.getBody());
        String objectKey = extractObjectKey(messageBody);
        
        if (objectKey == null) {
            context.getLogger().log("No object key found in apply completion message");
            return;
        }
        
        context.getLogger().log("Processing apply result: " + objectKey);
        
        // Download and analyze the apply result
        String applyContent = downloadS3Object(objectKey);
        TerraformApplyResult applyResult = analyzeApplyResult(applyContent, objectKey, context);
        
        // Generate AI summary
        String aiSummary = generateApplySummary(applyResult, context);
        
        // Send completion notification to Slack
        sendApplyCompletionNotification(applyResult, aiSummary, objectKey, context);
    }
    
    private String extractObjectKey(JsonNode messageBody) {
        // Try different message formats
        
        // Standard S3 event notification
        if (messageBody.has("Records")) {
            JsonNode records = messageBody.get("Records");
            if (records.isArray() && records.size() > 0) {
                JsonNode firstRecord = records.get(0);
                if (firstRecord.has("s3")) {
                    return firstRecord.get("s3").get("object").get("key").asText();
                }
            }
        }
        
        // Custom message format
        if (messageBody.has("objectKey")) {
            return messageBody.get("objectKey").asText();
        }
        
        // Direct object key
        if (messageBody.has("key")) {
            return messageBody.get("key").asText();
        }
        
        return null;
    }
    
    private String downloadS3Object(String objectKey) throws IOException {
        GetObjectRequest request = GetObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build();
        
        return s3Client.getObjectAsBytes(request).asString(StandardCharsets.UTF_8);
    }
    
    // Plan analysis methods (from PlanReviewerHandler)
    private TerraformPlanAnalysis analyzePlan(String planContent, Context context) throws IOException {
        JsonNode planJson = MAPPER.readTree(planContent);
        
        TerraformPlanAnalysis analysis = new TerraformPlanAnalysis();
        
        // Extract basic plan information
        if (planJson.has("resource_changes")) {
            JsonNode resourceChanges = planJson.get("resource_changes");
            
            for (JsonNode change : resourceChanges) {
                String action = change.get("change").get("actions").get(0).asText();
                String resourceType = change.get("type").asText();
                String resourceName = change.get("name").asText();
                
                switch (action) {
                    case "create":
                        analysis.resourcesToCreate++;
                        analysis.createActions.add(resourceType + "." + resourceName);
                        break;
                    case "update":
                        analysis.resourcesToUpdate++;
                        analysis.updateActions.add(resourceType + "." + resourceName);
                        break;
                    case "delete":
                        analysis.resourcesToDelete++;
                        analysis.deleteActions.add(resourceType + "." + resourceName);
                        break;
                }
            }
        }
        
        // Extract configuration information
        if (planJson.has("configuration")) {
            JsonNode config = planJson.get("configuration");
            if (config.has("root_module") && config.get("root_module").has("module_calls")) {
                analysis.moduleCount = config.get("root_module").get("module_calls").size();
            }
        }
        
        // Security analysis
        analysis.securityIssues = detectSecurityIssues(planJson);
        
        // Cost estimation
        analysis.estimatedMonthlyCost = estimateCost(analysis);
        
        context.getLogger().log("Plan analysis complete: " + analysis);
        return analysis;
    }
    
    private String generatePlanAIReview(TerraformPlanAnalysis analysis, Context context) {
        try {
            String prompt = buildPlanPrompt(analysis);
            
            String requestBody = MAPPER.writeValueAsString(Map.of(
                "model", "gpt-4o-mini",
                "messages", new Object[] {
                    Map.of(
                        "role", "system",
                        "content", "당신은 AWS 인프라 전문가입니다. Terraform plan을 분석하여 한국어로 간결하고 실용적인 리뷰를 제공해주세요."
                    ),
                    Map.of("role", "user", "content", prompt)
                },
                "max_tokens", 1000,
                "temperature", 0.3
            ));
            
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.openai.com/v1/chat/completions"))
                    .header("Authorization", "Bearer " + openaiApiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();
            
            HttpResponse<String> response = HTTP_CLIENT.send(request, 
                    HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() == 200) {
                JsonNode responseJson = MAPPER.readTree(response.body());
                return responseJson.get("choices").get(0).get("message").get("content").asText();
            } else {
                context.getLogger().log("OpenAI API error: " + response.statusCode() + " - " + response.body());
                return "AI 리뷰 생성 중 오류가 발생했습니다.";
            }
        } catch (Exception e) {
            context.getLogger().log("Error generating AI review: " + e.getMessage());
            return "AI 리뷰를 생성할 수 없습니다: " + e.getMessage();
        }
    }
    
    // Apply analysis methods (from ApplyReviewerHandler)
    private TerraformApplyResult analyzeApplyResult(String applyContent, String objectKey, Context context) {
        TerraformApplyResult result = new TerraformApplyResult();
        
        try {
            // Try to parse as JSON first (structured output)
            JsonNode applyJson = MAPPER.readTree(applyContent);
            
            if (applyJson.has("apply_result")) {
                JsonNode applyResult = applyJson.get("apply_result");
                result.success = "success".equals(applyResult.get("status").asText());
                result.resourcesCreated = applyResult.has("created") ? applyResult.get("created").asInt() : 0;
                result.resourcesUpdated = applyResult.has("updated") ? applyResult.get("updated").asInt() : 0;
                result.resourcesDestroyed = applyResult.has("destroyed") ? applyResult.get("destroyed").asInt() : 0;
            }
            
        } catch (Exception e) {
            // Fall back to text analysis
            result = parseTextApplyOutput(applyContent);
        }
        
        // Extract project info from object key
        String[] keyParts = objectKey.split("/");
        result.projectName = keyParts.length > 1 ? keyParts[1] : "Unknown";
        result.environment = keyParts.length > 2 ? keyParts[2] : "Unknown";
        result.timestamp = LocalDateTime.now();
        
        // Determine overall status
        if (applyContent.contains("Apply complete!") || applyContent.contains("No changes")) {
            result.success = true;
        } else if (applyContent.contains("Error:") || applyContent.contains("failed")) {
            result.success = false;
            result.errorMessage = extractErrorMessage(applyContent);
        }
        
        context.getLogger().log("Apply result analysis: " + result);
        return result;
    }
    
    private String generateApplySummary(TerraformApplyResult result, Context context) {
        try {
            String prompt = buildApplySummaryPrompt(result);
            
            String requestBody = MAPPER.writeValueAsString(Map.of(
                "model", "gpt-4o-mini",
                "messages", new Object[] {
                    Map.of(
                        "role", "system",
                        "content", "당신은 AWS 인프라 전문가입니다. Terraform apply 결과를 분석하여 한국어로 간결한 요약을 제공해주세요."
                    ),
                    Map.of("role", "user", "content", prompt)
                },
                "max_tokens", 500,
                "temperature", 0.2
            ));
            
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.openai.com/v1/chat/completions"))
                    .header("Authorization", "Bearer " + openaiApiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();
            
            HttpResponse<String> response = HTTP_CLIENT.send(request, 
                    HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() == 200) {
                JsonNode responseJson = MAPPER.readTree(response.body());
                return responseJson.get("choices").get(0).get("message").get("content").asText();
            } else {
                context.getLogger().log("OpenAI API error for apply summary: " + response.statusCode());
                return generateFallbackSummary(result);
            }
        } catch (Exception e) {
            context.getLogger().log("Error generating apply summary: " + e.getMessage());
            return generateFallbackSummary(result);
        }
    }
    
    // Helper methods (consolidated from both handlers)
    private String buildPlanPrompt(TerraformPlanAnalysis analysis) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("다음 Terraform Plan을 분석해주세요:\n\n");
        
        prompt.append("## 📊 변경 사항 요약\n");
        prompt.append("- 생성: ").append(analysis.resourcesToCreate).append("개 리소스\n");
        prompt.append("- 수정: ").append(analysis.resourcesToUpdate).append("개 리소스\n");
        prompt.append("- 삭제: ").append(analysis.resourcesToDelete).append("개 리소스\n");
        prompt.append("- 모듈 수: ").append(analysis.moduleCount).append("개\n\n");
        
        if (!analysis.createActions.isEmpty()) {
            prompt.append("## 🆕 생성될 리소스\n");
            analysis.createActions.forEach(resource -> 
                prompt.append("- ").append(resource).append("\n"));
            prompt.append("\n");
        }
        
        if (!analysis.updateActions.isEmpty()) {
            prompt.append("## 🔄 수정될 리소스\n");
            analysis.updateActions.forEach(resource -> 
                prompt.append("- ").append(resource).append("\n"));
            prompt.append("\n");
        }
        
        if (!analysis.deleteActions.isEmpty()) {
            prompt.append("## 🗑️ 삭제될 리소스\n");
            analysis.deleteActions.forEach(resource -> 
                prompt.append("- ").append(resource).append("\n"));
            prompt.append("\n");
        }
        
        if (!analysis.securityIssues.isEmpty()) {
            prompt.append("## 🚨 보안 이슈\n");
            analysis.securityIssues.forEach(issue -> 
                prompt.append("- ").append(issue).append("\n"));
            prompt.append("\n");
        }
        
        prompt.append("## 💰 예상 비용\n");
        prompt.append("월 예상 비용: ~$").append(analysis.estimatedMonthlyCost).append("\n\n");
        
        prompt.append("위 정보를 바탕으로:\n");
        prompt.append("1. 주요 변경사항에 대한 간단한 설명\n");
        prompt.append("2. 잠재적 위험 요소 (있다면)\n");
        prompt.append("3. 권장사항\n");
        prompt.append("4. 승인 여부 추천\n\n");
        prompt.append("간결하고 실용적인 리뷰를 제공해주세요.");
        
        return prompt.toString();
    }
    
    private String buildApplySummaryPrompt(TerraformApplyResult result) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("다음 Terraform Apply 결과를 요약해주세요:\n\n");
        
        prompt.append("## 배포 정보\n");
        prompt.append("- 프로젝트: ").append(result.projectName).append("\n");
        prompt.append("- 환경: ").append(result.environment).append("\n");
        prompt.append("- 상태: ").append(result.success ? "✅ 성공" : "❌ 실패").append("\n");
        prompt.append("- 시간: ").append(result.timestamp.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))).append("\n\n");
        
        prompt.append("## 리소스 변경사항\n");
        prompt.append("- 생성: ").append(result.resourcesCreated).append("개\n");
        prompt.append("- 수정: ").append(result.resourcesUpdated).append("개\n");
        prompt.append("- 삭제: ").append(result.resourcesDestroyed).append("개\n\n");
        
        if (!result.success && result.errorMessage != null) {
            prompt.append("## 오류 정보\n");
            prompt.append(result.errorMessage).append("\n\n");
        }
        
        prompt.append("위 정보를 바탕으로 간결한 배포 요약을 제공해주세요.");
        
        return prompt.toString();
    }
    
    private void sendPlanReviewNotification(TerraformPlanAnalysis analysis, String aiReview, 
                                          String objectKey, Context context) {
        try {
            // Extract project info from S3 key
            String[] keyParts = objectKey.split("/");
            String projectName = keyParts.length > 1 ? keyParts[1] : "Unknown";
            
            String slackMessage = buildPlanSlackMessage(analysis, aiReview, projectName);
            
            String requestBody = MAPPER.writeValueAsString(Map.of(
                "text", "🔍 Terraform Plan 리뷰 완료",
                "blocks", new Object[] {
                    Map.of(
                        "type", "section",
                        "text", Map.of(
                            "type", "mrkdwn",
                            "text", slackMessage
                        )
                    ),
                    Map.of("type", "divider"),
                    Map.of(
                        "type", "context",
                        "elements", new Object[] {
                            Map.of(
                                "type", "mrkdwn",
                                "text", "📁 파일: `" + objectKey + "`"
                            )
                        }
                    )
                }
            ));
            
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(slackWebhookUrl))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();
            
            HttpResponse<String> response = HTTP_CLIENT.send(request, 
                    HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() != 200) {
                context.getLogger().log("Slack notification failed: " + response.statusCode());
            }
        } catch (Exception e) {
            context.getLogger().log("Error sending Slack notification: " + e.getMessage());
        }
    }
    
    private void sendApplyCompletionNotification(TerraformApplyResult result, String aiSummary, 
                                               String objectKey, Context context) {
        try {
            String slackMessage = buildApplySlackMessage(result, aiSummary);
            String emoji = result.success ? "✅" : "❌";
            String status = result.success ? "완료" : "실패";
            
            String requestBody = MAPPER.writeValueAsString(Map.of(
                "text", emoji + " Terraform Apply " + status,
                "blocks", new Object[] {
                    Map.of(
                        "type", "header",
                        "text", Map.of(
                            "type", "plain_text",
                            "text", emoji + " Terraform Apply " + status
                        )
                    ),
                    Map.of(
                        "type", "section",
                        "text", Map.of(
                            "type", "mrkdwn",
                            "text", slackMessage
                        )
                    ),
                    Map.of("type", "divider"),
                    Map.of(
                        "type", "context",
                        "elements", new Object[] {
                            Map.of(
                                "type", "mrkdwn",
                                "text", String.format("📁 파일: `%s` | ⏰ %s", 
                                    objectKey, 
                                    result.timestamp.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
                                )
                            )
                        }
                    )
                }
            ));
            
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(slackWebhookUrl))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();
            
            HttpResponse<String> response = HTTP_CLIENT.send(request, 
                    HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() != 200) {
                context.getLogger().log("Slack notification failed: " + response.statusCode());
            }
        } catch (Exception e) {
            context.getLogger().log("Error sending apply completion notification: " + e.getMessage());
        }
    }
    
    private String buildPlanSlackMessage(TerraformPlanAnalysis analysis, String aiReview, String projectName) {
        StringBuilder message = new StringBuilder();
        
        message.append("*🏗️ 프로젝트:* `").append(projectName).append("`\n\n");
        
        message.append("*📊 변경 사항*\n");
        message.append("• 생성: ").append(analysis.resourcesToCreate).append("개\n");
        message.append("• 수정: ").append(analysis.resourcesToUpdate).append("개\n");
        message.append("• 삭제: ").append(analysis.resourcesToDelete).append("개\n");
        message.append("• 월 예상 비용: ~$").append(analysis.estimatedMonthlyCost).append("\n\n");
        
        if (!analysis.securityIssues.isEmpty()) {
            message.append("*🚨 보안 알림*\n");
            analysis.securityIssues.forEach(issue -> 
                message.append("• ").append(issue).append("\n"));
            message.append("\n");
        }
        
        message.append("*🤖 AI 리뷰*\n");
        message.append("```\n").append(aiReview).append("\n```");
        
        return message.toString();
    }
    
    private String buildApplySlackMessage(TerraformApplyResult result, String aiSummary) {
        StringBuilder message = new StringBuilder();
        
        message.append("*🏗️ 프로젝트:* `").append(result.projectName).append("`\n");
        message.append("*🌍 환경:* `").append(result.environment).append("`\n\n");
        
        message.append("*📊 변경사항*\n");
        message.append("• 생성: ").append(result.resourcesCreated).append("개\n");
        message.append("• 수정: ").append(result.resourcesUpdated).append("개\n");
        message.append("• 삭제: ").append(result.resourcesDestroyed).append("개\n\n");
        
        if (!result.success && result.errorMessage != null) {
            message.append("*🚨 오류 정보*\n");
            message.append("```\n").append(result.errorMessage).append("\n```\n\n");
        }
        
        message.append("*🤖 AI 요약*\n");
        message.append("```\n").append(aiSummary).append("\n```");
        
        return message.toString();
    }
    
    // Utility methods
    private java.util.List<String> detectSecurityIssues(JsonNode planJson) {
        java.util.List<String> issues = new java.util.ArrayList<>();
        
        if (planJson.has("resource_changes")) {
            for (JsonNode change : planJson.get("resource_changes")) {
                String resourceType = change.get("type").asText();
                JsonNode changeDetails = change.get("change");
                
                // Check for public access
                if (resourceType.equals("aws_security_group") && changeDetails.has("after")) {
                    JsonNode after = changeDetails.get("after");
                    if (after.has("ingress")) {
                        for (JsonNode ingress : after.get("ingress")) {
                            if (ingress.has("cidr_blocks")) {
                                for (JsonNode cidr : ingress.get("cidr_blocks")) {
                                    if ("0.0.0.0/0".equals(cidr.asText())) {
                                        issues.add("공개 인바운드 규칙 감지: " + change.get("name").asText());
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Check for unencrypted storage
                if ((resourceType.equals("aws_s3_bucket") || resourceType.equals("aws_rds_instance")) 
                    && changeDetails.has("after")) {
                    JsonNode after = changeDetails.get("after");
                    if (!after.has("encryption") || !after.get("encryption").asBoolean()) {
                        issues.add("암호화되지 않은 스토리지: " + change.get("name").asText());
                    }
                }
            }
        }
        
        return issues;
    }
    
    private double estimateCost(TerraformPlanAnalysis analysis) {
        // Enhanced cost estimation with Infracost integration (if available)
        if (infracostApiKey != null && !infracostApiKey.isEmpty()) {
            // TODO: Integrate with Infracost API for accurate cost estimation
        }
        
        // Fallback to heuristic-based estimation
        double cost = 0.0;
        cost += analysis.resourcesToCreate * 10.0; // $10 per new resource average
        cost += analysis.resourcesToUpdate * 2.0;  // $2 per updated resource
        
        return Math.round(cost * 100.0) / 100.0;
    }
    
    private TerraformApplyResult parseTextApplyOutput(String applyContent) {
        TerraformApplyResult result = new TerraformApplyResult();
        
        String[] lines = applyContent.split("\n");
        
        for (String line : lines) {
            line = line.trim();
            
            if (line.contains("Apply complete!") && line.contains("Resources:")) {
                String[] parts = line.split("Resources:");
                if (parts.length > 1) {
                    String resourceInfo = parts[1].trim();
                    
                    if (resourceInfo.contains("added")) {
                        result.resourcesCreated = extractNumber(resourceInfo, "added");
                    }
                    if (resourceInfo.contains("changed")) {
                        result.resourcesUpdated = extractNumber(resourceInfo, "changed");
                    }
                    if (resourceInfo.contains("destroyed")) {
                        result.resourcesDestroyed = extractNumber(resourceInfo, "destroyed");
                    }
                }
                result.success = true;
            }
            
            if (line.contains("Error:") || line.contains("failed")) {
                result.success = false;
                result.errorMessage = line;
            }
        }
        
        return result;
    }
    
    private int extractNumber(String text, String keyword) {
        try {
            int keywordIndex = text.indexOf(keyword);
            if (keywordIndex == -1) return 0;
            
            String beforeKeyword = text.substring(0, keywordIndex).trim();
            String[] words = beforeKeyword.split("\\s+");
            
            if (words.length > 0) {
                String lastWord = words[words.length - 1];
                return Integer.parseInt(lastWord.replaceAll("[^0-9]", ""));
            }
        } catch (Exception e) {
            // Ignore parsing errors
        }
        return 0;
    }
    
    private String extractErrorMessage(String applyContent) {
        String[] lines = applyContent.split("\n");
        StringBuilder errorMsg = new StringBuilder();
        
        boolean inError = false;
        for (String line : lines) {
            if (line.trim().startsWith("Error:")) {
                inError = true;
                errorMsg.append(line.trim()).append("\n");
            } else if (inError && line.trim().isEmpty()) {
                break;
            } else if (inError) {
                errorMsg.append(line.trim()).append("\n");
            }
        }
        
        return errorMsg.toString().trim();
    }
    
    private String generateFallbackSummary(TerraformApplyResult result) {
        if (result.success) {
            return String.format(
                "✅ 배포 완료!\n" +
                "총 %d개 리소스 변경 (생성: %d, 수정: %d, 삭제: %d)",
                result.getTotalChanges(),
                result.resourcesCreated,
                result.resourcesUpdated,
                result.resourcesDestroyed
            );
        } else {
            return String.format(
                "❌ 배포 실패\n" +
                "오류: %s",
                result.errorMessage != null ? result.errorMessage : "알 수 없는 오류"
            );
        }
    }
}