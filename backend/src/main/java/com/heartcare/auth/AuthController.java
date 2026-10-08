package com.heartcare.auth;

import com.heartcare.auth.dto.AuthResponse;
import com.heartcare.auth.dto.ChangePinRequest;
import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.PinChangeRequest;
import com.heartcare.auth.dto.RecoveryQuestionsRequest;
import com.heartcare.auth.dto.RefreshRequest;
import com.heartcare.auth.dto.ResetPinRequest;
import com.heartcare.auth.dto.SecurityQuestionsResponse;
import com.heartcare.auth.dto.SetSecurityAnswersRequest;
import com.heartcare.auth.model.SecurityQuestion;
import com.heartcare.auth.dto.RegisterRequest;
import com.heartcare.auth.dto.UserResponse;
import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import jakarta.validation.Valid;

import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final PinRecoveryService pinRecoveryService;
    private final SecurityAnswerService securityAnswerService;

    public AuthController(AuthService authService, PinRecoveryService pinRecoveryService,
                          SecurityAnswerService securityAnswerService) {
        this.authService = authService;
        this.pinRecoveryService = pinRecoveryService;
        this.securityAnswerService = securityAnswerService;
    }

    @PostMapping("/register")
    public ApiResponse<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ApiResponse.ok(authService.register(request), "Registered");
    }

    @PostMapping("/login")
    public ApiResponse<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.ok(authService.login(request), "Logged in");
    }

    @PostMapping("/refresh")
    public ApiResponse<AuthResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return ApiResponse.ok(authService.refresh(request.refreshToken()), "Token refreshed");
    }

    @PostMapping("/logout")
    public ApiResponse<Void> logout(@Valid @RequestBody RefreshRequest request) {
        authService.logout(request.refreshToken());
        return ApiResponse.ok(null, "Logged out");
    }

    /** PIN change without a session (the app's offline-capable path). See AuthService. */
    @PostMapping("/pin-change")
    public ApiResponse<AuthResponse> pinChange(@Valid @RequestBody PinChangeRequest request) {
        return ApiResponse.ok(authService.changePinWithCredentials(request), "PIN changed");
    }

    @PostMapping("/change-pin")
    public ApiResponse<AuthResponse> changePin(@AuthenticationPrincipal UserPrincipal principal,
                                               @Valid @RequestBody ChangePinRequest request) {
        return ApiResponse.ok(authService.changePin(principal.userId(), request), "PIN changed");
    }

    // ---- Forgot PIN (security questions) ----

    @GetMapping("/security-questions")
    public ApiResponse<List<SecurityQuestion>> securityQuestions() {
        return ApiResponse.ok(securityAnswerService.catalogue());
    }

    @GetMapping("/security-answers")
    public ApiResponse<SecurityQuestionsResponse> securityAnswerStatus(@AuthenticationPrincipal UserPrincipal principal) {
        return ApiResponse.ok(pinRecoveryService.status(principal.userId()));
    }

    @PutMapping("/security-answers")
    public ApiResponse<SecurityQuestionsResponse> setSecurityAnswers(@AuthenticationPrincipal UserPrincipal principal,
                                                                     @Valid @RequestBody SetSecurityAnswersRequest request) {
        return ApiResponse.ok(pinRecoveryService.replaceAnswers(
                principal.userId(), request.currentPin(), request.answers()), "Security answers saved");
    }

    @PostMapping("/recovery/questions")
    public ApiResponse<SecurityQuestionsResponse> recoveryQuestions(@Valid @RequestBody RecoveryQuestionsRequest request) {
        return ApiResponse.ok(pinRecoveryService.recoveryQuestions(request.phone()));
    }

    @PostMapping("/reset-pin")
    public ApiResponse<AuthResponse> resetPin(@Valid @RequestBody ResetPinRequest request) {
        return ApiResponse.ok(pinRecoveryService.resetPin(request), "PIN reset");
    }

    @GetMapping("/me")
    public ApiResponse<UserResponse> me(@AuthenticationPrincipal UserPrincipal principal) {
        return ApiResponse.ok(authService.getCurrentUser(principal.userId()));
    }
}
