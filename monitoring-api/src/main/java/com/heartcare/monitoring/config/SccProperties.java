package com.heartcare.monitoring.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.Map;

@ConfigurationProperties(prefix = "scc")
public record SccProperties(
        String prometheusUrl,
        String backendManagementUrl,
        String ngrokApiUrl,
        String databaseName,
        double slowQueryThresholdMs,
        long cacheTtlMs,
        Admin admin,
        Jwt jwt,
        Map<String, String> probes) {

    public record Admin(String username, String password) {
    }

    public record Jwt(String secret, long expirationMs) {
    }

    public SccProperties {
        probes = probes == null ? Map.of() : Map.copyOf(probes);
    }
}
