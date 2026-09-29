package com.heartcare.admin;

import com.heartcare.admin.dto.AdminLoginRequest;
import com.heartcare.admin.dto.AdminLoginResponse;
import com.heartcare.admin.dto.AdminMeResponse;
import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/auth")
public class AdminAuthController {

    private final AdminAuthService adminAuthService;

    public AdminAuthController(AdminAuthService adminAuthService) {
        this.adminAuthService = adminAuthService;
    }

    @PostMapping("/login")
    public ApiResponse<AdminLoginResponse> login(@Valid @RequestBody AdminLoginRequest request) {
        return ApiResponse.ok(adminAuthService.login(request), "Signed in");
    }

    @GetMapping("/me")
    public ApiResponse<AdminMeResponse> me(@AuthenticationPrincipal UserPrincipal principal) {
        return ApiResponse.ok(adminAuthService.me(principal.userId()));
    }
}
