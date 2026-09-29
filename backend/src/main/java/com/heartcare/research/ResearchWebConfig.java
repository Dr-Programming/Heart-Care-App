package com.heartcare.research;

import com.heartcare.research.audit.ResearchAuditInterceptor;
import com.heartcare.research.auth.ResearchAccessGuard;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class ResearchWebConfig implements WebMvcConfigurer {

    private final ResearchAuditInterceptor audit;
    private final ResearchAccessGuard guard;

    public ResearchWebConfig(ResearchAuditInterceptor audit, ResearchAccessGuard guard) {
        this.audit = audit;
        this.guard = guard;
    }

    /** Order matters: audit first, so a request the guard rejects is still recorded. */
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(audit).addPathPatterns("/api/v1/research/**").order(0);
        registry.addInterceptor(guard)
                .addPathPatterns("/api/v1/research/**")
                .excludePathPatterns("/api/v1/research/auth/login")
                .order(1);
    }
}
