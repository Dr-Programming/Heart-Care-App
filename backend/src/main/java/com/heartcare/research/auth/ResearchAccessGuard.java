package com.heartcare.research.auth;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.JwtTokenProvider;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.research.audit.ResearchAudit;
import com.heartcare.research.model.Researcher;
import com.heartcare.research.model.ResearcherGrant;
import com.heartcare.research.model.ResearcherStatus;
import com.heartcare.research.repository.ResearchSettingsRepository;
import com.heartcare.research.repository.ResearcherGrantRepository;
import com.heartcare.research.repository.ResearcherRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Set;

/**
 * Re-checks every researcher request against the database, so admin decisions take effect on
 * the very next request rather than when the 8-hour token runs out:
 *
 * <ul>
 *   <li>revoked account, or token issued before a revoke/reset (version mismatch): 401</li>
 *   <li>grant past its expiry: 401</li>
 *   <li>admin-issued password not yet replaced: 403 PASSWORD_CHANGE_REQUIRED, except on the
 *       two endpoints needed to replace it</li>
 * </ul>
 *
 * Runs as a MVC interceptor, after Spring Security has authenticated the RESEARCHER role.
 */
@Component
public class ResearchAccessGuard implements HandlerInterceptor {

    private static final Set<String> ALLOWED_BEFORE_CHANGE =
            Set.of("/api/v1/research/auth/me", "/api/v1/research/auth/change-password");

    private final ResearcherRepository researchers;
    private final ResearcherGrantRepository grants;
    private final ResearchSettingsRepository settings;
    private final JwtTokenProvider tokenProvider;
    private final ObjectMapper objectMapper;

    public ResearchAccessGuard(ResearcherRepository researchers, ResearcherGrantRepository grants,
                               ResearchSettingsRepository settings, JwtTokenProvider tokenProvider,
                               ObjectMapper objectMapper) {
        this.researchers = researchers;
        this.grants = grants;
        this.settings = settings;
        this.tokenProvider = tokenProvider;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal principal)) {
            return reject(response, 401, "SESSION_ENDED", "Sign in to continue.");
        }
        ResearchAudit.researcher(principal.userId());

        Researcher researcher = researchers.findById(principal.userId()).orElse(null);
        ResearcherGrant grant = researcher == null ? null : grants.findById(researcher.getId()).orElse(null);
        if (researcher == null || grant == null || researcher.getStatus() != ResearcherStatus.ACTIVE) {
            return reject(response, 401, "ACCESS_REVOKED", researcher != null && researcher.isArchived()
                    ? "Your research access has been removed. Contact your administrator."
                    : "Your research access has been revoked. Contact your administrator.");
        }
        if (!versionMatches(request, researcher)) {
            return reject(response, 401, "SESSION_ENDED", "Your session was ended by an administrator. Sign in again.");
        }
        if (grant.isExpired(OffsetDateTime.now(ZoneOffset.UTC))) {
            return reject(response, 401, "ACCESS_EXPIRED", "Your research access expired. Contact your administrator to extend it.");
        }
        if (researcher.isMustChangePassword() && !ALLOWED_BEFORE_CHANGE.contains(request.getRequestURI())) {
            return reject(response, 403, "PASSWORD_CHANGE_REQUIRED", "Change the password your administrator gave you before continuing.");
        }

        request.setAttribute(ResearchContext.ATTR, new ResearchContext(researcher, grant, settings.minGroupSize()));
        return true;
    }

    private boolean versionMatches(HttpServletRequest request, Researcher researcher) {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            return false;
        }
        try {
            Integer ver = tokenProvider.getClaim(header.substring(7), ResearchAuthService.VERSION_CLAIM, Integer.class);
            return ver != null && ver == researcher.getTokenVersion();
        } catch (RuntimeException ex) {
            return false;
        }
    }

    private boolean reject(HttpServletResponse response, int status, String code, String message) throws IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), new ApiResponse<>(false, Map.of("code", code), message,
                OffsetDateTime.now(ZoneOffset.UTC)));
        return false;
    }
}
