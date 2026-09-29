package com.heartcare.research.audit;

import com.heartcare.research.repository.ResearchAuditRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import tools.jackson.databind.ObjectMapper;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Writes one research_audit_log row for every researcher request, whatever its outcome:
 * sign-ins (including failures), guard rejections, validation errors and successful analyses.
 * Registered ahead of {@link com.heartcare.research.auth.ResearchAccessGuard} so its
 * afterCompletion still runs when the guard turns a request away.
 */
@Component
public class ResearchAuditInterceptor implements HandlerInterceptor {

    private static final String STARTED = "research.audit.started";
    private static final Logger log = LoggerFactory.getLogger(ResearchAuditInterceptor.class);

    private final ResearchAuditRepository repository;
    private final ObjectMapper objectMapper;

    public ResearchAuditInterceptor(ResearchAuditRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        request.setAttribute(STARTED, System.nanoTime());
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
        try {
            Long started = (Long) request.getAttribute(STARTED);
            int durationMs = started == null ? 0 : (int) ((System.nanoTime() - started) / 1_000_000);
            repository.insert(new ResearchAuditRepository.Entry(
                    (UUID) request.getAttribute(ResearchAudit.RESEARCHER_ID),
                    (String) request.getAttribute(ResearchAudit.USERNAME),
                    request.getMethod(),
                    request.getRequestURI(),
                    paramsJson(request),
                    response.getStatus(),
                    (Integer) request.getAttribute(ResearchAudit.ROWS),
                    durationMs,
                    clientIp(request),
                    request.getHeader("User-Agent")));
        } catch (RuntimeException e) {
            // An audit failure must be loud, but must not turn a served response into an error.
            log.error("Failed to write research audit entry for {} {}", request.getMethod(), request.getRequestURI(), e);
        }
    }

    private String paramsJson(HttpServletRequest request) {
        Map<String, Object> params = new LinkedHashMap<>();
        request.getParameterMap().forEach((k, v) -> params.put(k,
                k.toLowerCase(java.util.Locale.ROOT).contains("password") ? "[redacted]" : (v.length == 1 ? v[0] : v)));
        Object body = request.getAttribute(ResearchAudit.PARAMS);
        if (body != null) {
            params.put("body", body);
        }
        return params.isEmpty() ? null : objectMapper.writeValueAsString(params);
    }

    /** Behind the nginx proxy the socket address is the proxy; prefer the forwarded client. */
    private static String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
