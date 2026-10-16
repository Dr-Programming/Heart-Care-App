package com.heartcare.common.monitoring;

import java.time.Instant;

/** One anonymised timeline entry. Deliberately has no user id, path or payload. */
public record ActivityEvent(Instant at, String client, String category, String label,
                            String outcome, long durationMs) {

    static String outcomeOf(int status) {
        if (status >= 500) {
            return "server_error";
        }
        if (status >= 400) {
            return "client_error";
        }
        return "success";
    }
}
