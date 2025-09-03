package com.stackkit.atlantis.reviewer;

import java.time.LocalDateTime;

/**
 * Data class representing the result of a Terraform apply operation
 */
public class TerraformApplyResult {
    
    public boolean success = false;
    public String projectName = "Unknown";
    public String environment = "Unknown";
    public LocalDateTime timestamp = LocalDateTime.now();
    
    public int resourcesCreated = 0;
    public int resourcesUpdated = 0;
    public int resourcesDestroyed = 0;
    
    public String errorMessage;
    public String outputLog;
    
    public int getTotalChanges() {
        return resourcesCreated + resourcesUpdated + resourcesDestroyed;
    }
    
    public boolean hasChanges() {
        return getTotalChanges() > 0;
    }
    
    public boolean isSuccessWithChanges() {
        return success && hasChanges();
    }
    
    public String getStatusEmoji() {
        if (success) {
            return hasChanges() ? "✅" : "ℹ️";
        } else {
            return "❌";
        }
    }
    
    public String getStatusText() {
        if (success) {
            return hasChanges() ? "Apply 완료" : "변경사항 없음";
        } else {
            return "Apply 실패";
        }
    }
    
    @Override
    public String toString() {
        return String.format(
            "TerraformApplyResult{project=%s, env=%s, success=%s, created=%d, updated=%d, destroyed=%d}",
            projectName, environment, success, resourcesCreated, resourcesUpdated, resourcesDestroyed
        );
    }
}