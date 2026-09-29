package com.heartcare.admin;

import com.heartcare.common.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Logs every admin read of patient data: who looked, at what. Health records are sensitive
 * enough that access should leave a trail even when nothing is modified. Uses its own logger
 * name ("admin-audit") so it can be routed to a separate appender later.
 */
@Configuration
public class AdminAuditInterceptor implements HandlerInterceptor, WebMvcConfigurer {

    private static final Logger audit = LoggerFactory.getLogger("admin-audit");

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(this)
                .addPathPatterns("/api/v1/admin/**")
                .excludePathPatterns("/api/v1/admin/auth/**");
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                Object handler, Exception ex) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String adminId = auth != null && auth.getPrincipal() instanceof UserPrincipal p
                ? p.userId().toString() : "unknown";
        String query = request.getQueryString();
        audit.info("admin={} {} {}{} -> {}", adminId, request.getMethod(), request.getRequestURI(),
                query == null ? "" : "?" + query, response.getStatus());
    }
}
