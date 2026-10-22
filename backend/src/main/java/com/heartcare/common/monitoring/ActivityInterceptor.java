// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.common.monitoring;

import com.heartcare.common.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Feeds {@link ActivityRecorder} from every completed API request. */
@Configuration
public class ActivityInterceptor implements HandlerInterceptor, WebMvcConfigurer {

    private static final String START = ActivityInterceptor.class.getName() + ".start";

    private final ActivityRecorder recorder;

    public ActivityInterceptor(ActivityRecorder recorder) {
        this.recorder = recorder;
    }

    /** Runs first, so a request another interceptor rejects is still timed and counted. */
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(this).addPathPatterns("/api/v1/**").order(-10);
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        request.setAttribute(START, System.nanoTime());
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                Object handler, Exception ex) {
        Object start = request.getAttribute(START);
        long durationMs = start instanceof Long s ? (System.nanoTime() - s) / 1_000_000 : 0;
        Object pattern = request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
        int status = ex != null && response.getStatus() < 400 ? 500 : response.getStatus();
        recorder.record(ClientType.fromPath(request.getRequestURI()),
                ActivityCategory.classify(request.getMethod(), pattern == null ? null : pattern.toString()),
                status, durationMs);

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof UserPrincipal p) {
            recorder.seen(p.role(), p.userId().toString());
        }
    }
}
