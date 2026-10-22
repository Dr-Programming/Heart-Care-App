// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.auth;

import com.heartcare.monitoring.common.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;

@RestController
@RequestMapping("/api/monitoring/auth")
public class AuthController {

    private final SccCredentials credentials;
    private final SccTokenService tokens;
    private final LoginRateLimiter limiter;

    public AuthController(SccCredentials credentials, SccTokenService tokens, LoginRateLimiter limiter) {
        this.credentials = credentials;
        this.tokens = tokens;
        this.limiter = limiter;
    }

    public record LoginRequest(@NotBlank @Size(max = 100) String username,
                               @NotBlank @Size(max = 200) String password) {
    }

    public record LoginResponse(String token, Instant expiresAt, String username) {
    }

    public record MeResponse(String username) {
    }

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@Valid @RequestBody LoginRequest body, HttpServletRequest request) {
        String client = clientIp(request);
        if (!limiter.tryAcquire(client)) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Too many sign-in attempts. Try again in a few minutes.");
        }
        if (!credentials.matches(body.username(), body.password())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid username or password");
        }
        limiter.reset(client);
        SccTokenService.IssuedToken issued = tokens.issue(body.username());
        return ApiResponse.ok(new LoginResponse(issued.token(), issued.expiresAt(), body.username()));
    }

    @GetMapping("/me")
    public ApiResponse<MeResponse> me(Authentication authentication) {
        return ApiResponse.ok(new MeResponse(authentication.getName()));
    }

    /**
     * scc-web's nginx is the only way in and it sets X-Real-IP, so the header can be trusted here;
     * the API port itself is never published.
     */
    private static String clientIp(HttpServletRequest request) {
        String real = request.getHeader("X-Real-IP");
        return real == null || real.isBlank() ? request.getRemoteAddr() : real.trim();
    }
}
