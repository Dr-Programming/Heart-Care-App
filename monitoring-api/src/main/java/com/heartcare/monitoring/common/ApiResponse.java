package com.heartcare.monitoring.common;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/** Same envelope as the main backend, so the dashboard can reuse the admin panel's client code. */
public record ApiResponse<T>(boolean success, T data, String message, OffsetDateTime timestamp) {

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, "OK", OffsetDateTime.now(ZoneOffset.UTC));
    }

    public static <T> ApiResponse<T> error(String message) {
        return new ApiResponse<>(false, null, message, OffsetDateTime.now(ZoneOffset.UTC));
    }
}
