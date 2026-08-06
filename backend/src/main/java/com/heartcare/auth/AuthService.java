package com.heartcare.auth;

import com.heartcare.auth.dto.AuthResponse;
import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.RegisterRequest;
import com.heartcare.auth.dto.UserResponse;
import com.heartcare.auth.model.User;
import com.heartcare.common.exception.ConflictException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.exception.UnauthorizedException;
import com.heartcare.common.security.JwtTokenProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class AuthService {

    /**
     * One message for both "no such phone" and "wrong PIN". Anything more specific would turn
     * login into an account-enumeration oracle.
     */
    static final String INVALID_CREDENTIALS = "Invalid phone or PIN";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider tokenProvider) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByPhone(request.phone())) {
            throw new ConflictException("Phone already registered");
        }
        User user = new User(
                request.phone(),
                passwordEncoder.encode(request.pin()),
                request.name(),
                request.preferredLanguage());
        try {
            userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException ex) {
            // Two registrations for the same phone racing past the existsByPhone check.
            throw new ConflictException("Phone already registered");
        }
        return authResponseFor(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByPhone(request.phone())
                .orElseThrow(() -> new UnauthorizedException(INVALID_CREDENTIALS));
        if (!passwordEncoder.matches(request.pin(), user.getPinHash())) {
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }
        return authResponseFor(user);
    }

    @Transactional(readOnly = true)
    public UserResponse getCurrentUser(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        return toUserResponse(user);
    }

    private AuthResponse authResponseFor(User user) {
        String token = tokenProvider.generateToken(user.getId(), user.getRole());
        return new AuthResponse(token, toUserResponse(user));
    }

    private UserResponse toUserResponse(User user) {
        return new UserResponse(
                user.getId().toString(),
                user.getFullName(),
                user.getPhone(),
                user.getPreferredLanguage(),
                user.getRole());
    }
}
