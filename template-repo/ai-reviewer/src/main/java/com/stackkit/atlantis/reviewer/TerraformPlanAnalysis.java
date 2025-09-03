package com.stackkit.atlantis.reviewer;

import java.util.ArrayList;
import java.util.List;

/**
 * Data class representing analysis results of a Terraform plan
 */
public class TerraformPlanAnalysis {
    
    public int resourcesToCreate = 0;
    public int resourcesToUpdate = 0;
    public int resourcesToDelete = 0;
    public int moduleCount = 0;
    
    public List<String> createActions = new ArrayList<>();
    public List<String> updateActions = new ArrayList<>(); 
    public List<String> deleteActions = new ArrayList<>();
    
    public List<String> securityIssues = new ArrayList<>();
    public double estimatedMonthlyCost = 0.0;
    
    public boolean hasChanges() {
        return resourcesToCreate > 0 || resourcesToUpdate > 0 || resourcesToDelete > 0;
    }
    
    public boolean isHighRisk() {
        return resourcesToDelete > 0 || !securityIssues.isEmpty() || estimatedMonthlyCost > 200.0;
    }
    
    public String getSeverity() {
        if (isHighRisk()) {
            return "HIGH";
        } else if (resourcesToCreate > 5 || resourcesToUpdate > 10) {
            return "MEDIUM";
        } else {
            return "LOW";
        }
    }
    
    public int getTotalChanges() {
        return resourcesToCreate + resourcesToUpdate + resourcesToDelete;
    }
    
    @Override
    public String toString() {
        return String.format(
            "TerraformPlanAnalysis{create=%d, update=%d, delete=%d, modules=%d, cost=$%.2f, security=%d}",
            resourcesToCreate, resourcesToUpdate, resourcesToDelete, 
            moduleCount, estimatedMonthlyCost, securityIssues.size()
        );
    }
}