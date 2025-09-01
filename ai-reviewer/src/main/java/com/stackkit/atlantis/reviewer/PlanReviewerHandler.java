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
import java.util.Map;

/**
 * AWS Lambda handler for AI-powered Terraform plan reviews
 * Processes SQS messages triggered by S3 events when Atlantis uploads plan files
 */
public class PlanReviewerHandler implements RequestHandler<SQSEvent, String> {
    
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final HttpClient HTTP_CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(30))
            .build();
    
    private final S3Client s3Client;
    private final String bucketName;
    private final String slackWebhookUrl;
    private final String openaiApiKey;
    
    public PlanReviewerHandler() {
        this.s3Client = S3Client.create();
        this.bucketName = System.getenv("S3_BUCKET");
        this.slackWebhookUrl = System.getenv("SLACK_WEBHOOK_URL");
        this.openaiApiKey = System.getenv("OPENAI_API_KEY");
    }
    
    @Override
    public String handleRequest(SQSEvent event, Context context) {
        context.getLogger().log("Processing " + event.getRecords().size() + " SQS records");
        
        for (SQSEvent.SQSMessage message : event.getRecords()) {
            try {
                processMessage(message, context);
            } catch (Exception e) {
                context.getLogger().log("Error processing message: " + e.getMessage());
                // Allow partial failures - don't throw exception
            }
        }
        
        return "Processed " + event.getRecords().size() + " messages";
    }
    
    private void processMessage(SQSEvent.SQSMessage message, Context context) throws Exception {
        // Parse S3 event from SQS message
        JsonNode s3Event = MAPPER.readTree(message.getBody());
        JsonNode records = s3Event.get("Records");
        
        if (records == null || !records.isArray() || records.size() == 0) {
            context.getLogger().log("No S3 records found in message");
            return;
        }
        
        for (JsonNode record : records) {
            JsonNode s3 = record.get("s3");
            if (s3 == null) continue;
            
            String objectKey = s3.get("object").get("key").asText();
            context.getLogger().log("Processing S3 object: " + objectKey);
            
            // Download and analyze the plan file
            String planContent = downloadS3Object(objectKey);
            TerraformPlanAnalysis analysis = analyzePlan(planContent, context);
            
            // Generate AI review
            String aiReview = generateAIReview(analysis, context);
            
            // Send to Slack
            sendSlackNotification(analysis, aiReview, objectKey, context);
        }
    }
    
    private String downloadS3Object(String objectKey) throws IOException {
        GetObjectRequest request = GetObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build();
        
        return s3Client.getObjectAsBytes(request).asString(StandardCharsets.UTF_8);
    }
    
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
        
        // Cost estimation (basic)
        analysis.estimatedMonthlyCost = estimateCost(analysis);
        
        context.getLogger().log("Plan analysis complete: " + analysis);
        return analysis;
    }
    
    private String generateAIReview(TerraformPlanAnalysis analysis, Context context) {
        try {
            String prompt = buildPrompt(analysis);
            
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
    
    private String buildPrompt(TerraformPlanAnalysis analysis) {
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
    
    private void sendSlackNotification(TerraformPlanAnalysis analysis, String aiReview, 
                                     String objectKey, Context context) {
        try {
            // Extract project info from S3 key
            String[] keyParts = objectKey.split("/");
            String projectName = keyParts.length > 1 ? keyParts[1] : "Unknown";
            
            String slackMessage = buildSlackMessage(analysis, aiReview, projectName, objectKey);
            
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
    
    private String buildSlackMessage(TerraformPlanAnalysis analysis, String aiReview, 
                                   String projectName, String objectKey) {
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
        // Basic cost estimation logic
        double cost = 0.0;
        
        // Simple heuristic based on resource types and counts
        cost += analysis.resourcesToCreate * 10.0; // $10 per new resource average
        cost += analysis.resourcesToUpdate * 2.0;  // $2 per updated resource
        
        return Math.round(cost * 100.0) / 100.0;
    }
}