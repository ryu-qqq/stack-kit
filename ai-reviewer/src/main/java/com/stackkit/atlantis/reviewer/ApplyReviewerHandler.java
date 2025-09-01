package com.stackkit.atlantis.reviewer;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;

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
 * AWS Lambda handler for AI-powered Terraform apply reviews
 * Processes SQS messages triggered by S3 events when Atlantis completes apply operations
 */
public class ApplyReviewerHandler implements RequestHandler<SQSEvent, String> {
    
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final HttpClient HTTP_CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(30))
            .build();
    
    private final S3Client s3Client;
    private final String bucketName;
    private final String slackWebhookUrl;
    private final String openaiApiKey;
    
    public ApplyReviewerHandler() {
        this.s3Client = S3Client.create();
        this.bucketName = System.getenv("S3_BUCKET");
        this.slackWebhookUrl = System.getenv("SLACK_WEBHOOK_URL");
        this.openaiApiKey = System.getenv("OPENAI_API_KEY");
    }
    
    @Override
    public String handleRequest(SQSEvent event, Context context) {
        context.getLogger().log("Processing " + event.getRecords().size() + " apply review SQS records");
        
        for (SQSEvent.SQSMessage message : event.getRecords()) {
            try {
                processApplyMessage(message, context);
            } catch (Exception e) {
                context.getLogger().log("Error processing apply message: " + e.getMessage());
                // Allow partial failures
            }
        }
        
        return "Processed " + event.getRecords().size() + " apply messages";
    }
    
    private void processApplyMessage(SQSEvent.SQSMessage message, Context context) throws Exception {
        // Parse S3 event from SQS message
        JsonNode s3Event = MAPPER.readTree(message.getBody());
        JsonNode records = s3Event.get("Records");
        
        if (records == null || !records.isArray() || records.size() == 0) {
            context.getLogger().log("No S3 records found in apply message");
            return;
        }
        
        for (JsonNode record : records) {
            JsonNode s3 = record.get("s3");
            if (s3 == null) continue;
            
            String objectKey = s3.get("object").get("key").asText();
            context.getLogger().log("Processing apply result: " + objectKey);
            
            // Download and analyze the apply result
            String applyContent = downloadS3Object(objectKey);
            TerraformApplyResult applyResult = analyzeApplyResult(applyContent, objectKey, context);
            
            // Generate AI summary
            String aiSummary = generateApplySummary(applyResult, context);
            
            // Send completion notification to Slack
            sendApplyCompletionNotification(applyResult, aiSummary, objectKey, context);
        }
    }
    
    private String downloadS3Object(String objectKey) {
        try {
            GetObjectRequest request = GetObjectRequest.builder()
                    .bucket(bucketName)
                    .key(objectKey)
                    .build();
            
            return s3Client.getObjectAsBytes(request).asString(StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "Error downloading file: " + e.getMessage();
        }
    }
    
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
    
    private TerraformApplyResult parseTextApplyOutput(String applyContent) {
        TerraformApplyResult result = new TerraformApplyResult();
        
        // Parse Terraform apply output using text patterns
        String[] lines = applyContent.split("\n");
        
        for (String line : lines) {
            line = line.trim();
            
            // Look for resource creation/modification/destruction patterns
            if (line.contains("Apply complete!") && line.contains("Resources:")) {
                // Example: "Apply complete! Resources: 3 added, 1 changed, 0 destroyed."
                String[] parts = line.split("Resources:");
                if (parts.length > 1) {
                    String resourceInfo = parts[1].trim();
                    
                    // Extract numbers using regex-like approach
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
            
            // Check for errors
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
            
            // Look backwards for the number
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
}