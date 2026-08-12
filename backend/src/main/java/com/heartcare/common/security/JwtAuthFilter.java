package com.heartcare.common.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtTokenProvider tokenProvider;

    public JwtAuthFilter(JwtTokenProvider tokenProvider) {
        this.tokenProvider = tokenProvider;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith(BEARER_PREFIX)) {
            String token = header.substring(BEARER_PREFIX.length());
            if (tokenProvider.validateToken(token)) {
                authenticate(token);
            }
        }
        filterChain.doFilter(request, response);
    }

    /**
     * A signature-valid token can still carry unusable claims (non-UUID subject, absent role).
     * Leaving the context unauthenticated yields a clean 401 from the entry point; letting the
     * parse failure escape a filter would bypass GlobalExceptionHandler and surface a container
     * error page instead.
     */
    private void authenticate(String token) {
        UUID userId;
        try {
            userId = UUID.fromString(tokenProvider.getUserId(token));
        } catch (IllegalArgumentException | NullPointerException ex) {
            return;
        }
        String role = tokenProvider.getRole(token);
        if (role == null || role.isBlank()) {
            return;
        }
        UserPrincipal principal = new UserPrincipal(userId, role);
        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                        principal, null,
                        List.of(new SimpleGrantedAuthority("ROLE_" + role)));
        SecurityContextHolder.getContext().setAuthentication(authentication);
    }
}
