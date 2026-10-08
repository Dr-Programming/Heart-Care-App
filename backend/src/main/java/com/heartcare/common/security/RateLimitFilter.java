package com.heartcare.common.security;

import com.heartcare.common.response.ApiResponse;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.time.Clock;
import java.time.Duration;
import java.util.Map;

/**
 * Per-IP throttle on the unauthenticated patient endpoints that create state or mint tokens
 * (T-SEC-05): registration (account spam, phone-number squatting), token refresh (guessing), and
 * forgot-PIN recovery (answer guessing across many accounts; each account also has its own lockout).
 * Login is already covered by the per-account PIN lockout.
 *
 * <p>Keyed on {@link HttpServletRequest#getRemoteAddr()}, never on a client-supplied
 * X-Forwarded-For, which any caller can forge to get a fresh bucket per request. Behind a reverse
 * proxy, set {@code server.forward-headers-strategy=native} so the container resolves the real
 * client address from the proxy's header instead.
 *
 * <p>Registered inside the Spring Security chain (see SecurityConfig), so it runs before any
 * authentication work and MockMvc tests built with springSecurity() exercise it.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final ObjectMapper objectMapper;
    private final Map<String, FixedWindowRateLimiter> limitersByPath;

    public RateLimitFilter(ObjectMapper objectMapper,
                           @Value("${app.rate-limit.register.max-requests}") int registerMax,
                           @Value("${app.rate-limit.register.window-seconds}") long registerWindowSeconds,
                           @Value("${app.rate-limit.refresh.max-requests}") int refreshMax,
                           @Value("${app.rate-limit.refresh.window-seconds}") long refreshWindowSeconds,
                           @Value("${app.rate-limit.reset-pin.max-requests}") int resetMax,
                           @Value("${app.rate-limit.reset-pin.window-seconds}") long resetWindowSeconds,
                           @Value("${app.rate-limit.recovery-questions.max-requests}") int questionsMax,
                           @Value("${app.rate-limit.recovery-questions.window-seconds}") long questionsWindowSeconds) {
        this.objectMapper = objectMapper;
        Clock clock = Clock.systemUTC();
        this.limitersByPath = Map.of(
                "/api/v1/auth/register",
                new FixedWindowRateLimiter(registerMax, Duration.ofSeconds(registerWindowSeconds), clock),
                "/api/v1/auth/refresh",
                new FixedWindowRateLimiter(refreshMax, Duration.ofSeconds(refreshWindowSeconds), clock),
                "/api/v1/auth/reset-pin",
                new FixedWindowRateLimiter(resetMax, Duration.ofSeconds(resetWindowSeconds), clock),
                "/api/v1/auth/recovery/questions",
                new FixedWindowRateLimiter(questionsMax, Duration.ofSeconds(questionsWindowSeconds), clock));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        FixedWindowRateLimiter limiter = "POST".equals(request.getMethod())
                ? limitersByPath.get(request.getRequestURI())
                : null;
        if (limiter != null) {
            String key = request.getRemoteAddr();
            if (!limiter.tryAcquire(key)) {
                response.setStatus(429);
                response.setHeader("Retry-After", Long.toString(limiter.retryAfterSeconds(key)));
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                objectMapper.writeValue(response.getWriter(),
                        ApiResponse.error("Too many requests. Try again later."));
                return;
            }
        }
        filterChain.doFilter(request, response);
    }
}
