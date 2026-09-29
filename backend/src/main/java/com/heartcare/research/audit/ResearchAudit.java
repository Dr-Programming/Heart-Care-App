package com.heartcare.research.audit;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.UUID;

/**
 * Lets request-handling code enrich the audit row that {@link ResearchAuditInterceptor} writes at
 * the end of each researcher request: who (for sign-in, before any token exists), what the
 * analysis asked for (POST bodies are not otherwise visible to the interceptor), and how many
 * rows or groups came back.
 */
public final class ResearchAudit {

    static final String RESEARCHER_ID = "research.audit.researcherId";
    static final String USERNAME = "research.audit.username";
    static final String PARAMS = "research.audit.params";
    static final String ROWS = "research.audit.rows";

    private ResearchAudit() {
    }

    public static void researcher(UUID researcherId) {
        set(RESEARCHER_ID, researcherId);
    }

    public static void usernameAttempted(String username) {
        set(USERNAME, username);
    }

    /** The request body or analysis definition, recorded as JSON. Never pass passwords here. */
    public static void params(Object params) {
        set(PARAMS, params);
    }

    public static void rows(long rows) {
        set(ROWS, (int) Math.min(Integer.MAX_VALUE, rows));
    }

    private static void set(String key, Object value) {
        RequestAttributes attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            HttpServletRequest request = sra.getRequest();
            request.setAttribute(key, value);
        }
    }
}
