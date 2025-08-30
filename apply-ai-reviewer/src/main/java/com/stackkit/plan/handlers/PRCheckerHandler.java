package com.stackkit.plan.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.stackkit.plan.model.Models.Manifest;
import com.stackkit.plan.util.Common;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * 입력: { manifest:{ repo:"owner/name", pr:123, ... }, ... }
 * 출력: 입력 + { proceed:true/false, reason:"..." }
 * 환경: GITHUB_TOKEN (없으면 proceed=true)
 */
public class PRCheckerHandler implements RequestHandler<Map<String,Object>, Map<String,Object>> {
    @Override
    public Map<String, Object> handleRequest(Map<String, Object> input, Context context) {
        Map<String,Object> manifestMap = (Map<String, Object>) input.get("manifest");
        Manifest man = Common.M.convertValue(manifestMap, Manifest.class);

        boolean proceed = true;
        String reason = "ok";
        String token = System.getenv("GITHUB_TOKEN");

        try {
            if (token != null && !token.isBlank()) {
                String url = "https://api.github.com/repos/" + man.repo() + "/pulls/" + man.pr();
                var req = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofSeconds(5))
                    .header("Accept","application/vnd.github+json")
                    .header("Authorization","Bearer " + token)
                    .GET().build();
                var res = HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                if (res.statusCode() == 200) {
                    Map<String,Object> pr = Common.M.readValue(res.body(), new com.fasterxml.jackson.core.type.TypeReference<Map<String,Object>>() {});
                    String state = (String) pr.get("state"); // open/closed
                    Boolean merged = (Boolean) pr.getOrDefault("merged", Boolean.FALSE);
                    if (!"open".equalsIgnoreCase(state) || Boolean.TRUE.equals(merged)) {
                        proceed = false; reason = "pr-closed-or-merged";
                    }
                }
            }
        } catch (Exception e) {
            // GitHub 조회 실패는 파이프라인을 막지 않도록 허용
            proceed = true; reason = "github-check-failed:" + e.getMessage();
        }

        Map<String,Object> out = new HashMap<>(input);
        out.put("proceed", proceed);
        out.put("reason", reason);
        return out;
    }
}
