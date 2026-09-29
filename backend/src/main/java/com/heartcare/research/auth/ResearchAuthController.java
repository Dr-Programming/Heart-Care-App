package com.heartcare.research.auth;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.research.dto.ChangePasswordRequest;
import com.heartcare.research.dto.ResearchLoginRequest;
import com.heartcare.research.dto.ResearchLoginResponse;
import com.heartcare.research.dto.ResearcherMe;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Researcher sign-in and account. There are deliberately no endpoints to edit the profile. */
@RestController
@RequestMapping("/api/v1/research/auth")
public class ResearchAuthController {

    private final ResearchAuthService service;

    public ResearchAuthController(ResearchAuthService service) {
        this.service = service;
    }

    @PostMapping("/login")
    public ApiResponse<ResearchLoginResponse> login(@Valid @RequestBody ResearchLoginRequest request) {
        return ApiResponse.ok(service.login(request), "Signed in");
    }

    @GetMapping("/me")
    public ApiResponse<ResearcherMe> me(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx) {
        return ApiResponse.ok(service.me(ctx));
    }

    @PostMapping("/change-password")
    public ApiResponse<ResearcherMe> changePassword(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                                    @Valid @RequestBody ChangePasswordRequest request) {
        return ApiResponse.ok(service.changePassword(ctx, request), "Password changed");
    }
}
