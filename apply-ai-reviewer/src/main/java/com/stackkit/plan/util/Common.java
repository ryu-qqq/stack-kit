package com.stackkit.plan.util;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectResponse;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import java.util.Optional;

public class Common {
    public static final ObjectMapper M = new ObjectMapper();

    public static String region() {
        return Optional.ofNullable(System.getenv("AWS_REGION")).orElse("ap-northeast-2");
    }

    public static S3Client s3() {
        return S3Client.builder()
            .region(Region.of(region()))
            .credentialsProvider(DefaultCredentialsProvider.create())
            .build();
    }

    public static S3Presigner presigner() {
        return S3Presigner.builder()
            .region(Region.of(region()))
            .credentialsProvider(DefaultCredentialsProvider.create())
            .build();
    }

    public static DynamoDbClient ddb() {
        return DynamoDbClient.builder()
            .region(Region.of(region()))
            .credentialsProvider(DefaultCredentialsProvider.create())
            .build();
    }

    public static byte[] getBytes(S3Client s3, String bucket, String key) {
        return s3.getObjectAsBytes(GetObjectRequest.builder().bucket(bucket).key(key).build()).asByteArray();
    }

    public static HeadObjectResponse head(S3Client s3, String bucket, String key) {
        return s3.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build());
    }

    public static String presign(S3Presigner p, String bucket, String key, long ttlSeconds) {
        var req = software.amazon.awssdk.services.s3.model.GetObjectRequest.builder()
            .bucket(bucket).key(key).build();
        var pre = p.presignGetObject(GetObjectPresignRequest.builder()
            .getObjectRequest(req).signatureDuration(Duration.ofSeconds(ttlSeconds)).build());
        return pre.url().toString();
    }

    public static void sendSlack(String webhook, String text) throws Exception {
        var req = HttpRequest.newBuilder(URI.create(webhook))
            .timeout(Duration.ofSeconds(5))
            .header("Content-Type","application/json")
            .POST(HttpRequest.BodyPublishers.ofString("{\"text\":" + M.writeValueAsString(text) + "}", StandardCharsets.UTF_8))
            .build();
        HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.ofString());
    }

    public static boolean idempotentPut(DynamoDbClient ddb, String table, String pk, Map<String, String> extra) {
        try {
            var item = new java.util.HashMap<String, AttributeValue>();
            item.put("pk", AttributeValue.builder().s(pk).build());
            if (extra != null) {
                for (var e : extra.entrySet()) {
                    item.put(e.getKey(), AttributeValue.builder().s(e.getValue()).build());
                }
            }
            ddb.putItem(PutItemRequest.builder()
                .tableName(table)
                .item(item)
                .conditionExpression("attribute_not_exists(pk)")
                .build());
            return true;
        } catch (ConditionalCheckFailedException e) {
            return false; // 이미 처리됨
        }
    }

    public static Map<String, Object> jsonToMap(byte[] bytes) throws Exception {
        return M.readValue(bytes, new TypeReference<Map<String, Object>>() {});
    }
}
