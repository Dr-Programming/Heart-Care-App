package com.heartcare.auth;

import com.heartcare.auth.dto.AuthResponse;
import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.RegisterRequest;
import com.heartcare.auth.model.User;
import com.heartcare.common.exception.ConflictException;
import com.heartcare.common.exception.UnauthorizedException;
import com.heartcare.common.security.JwtTokenProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    UserRepository userRepository;

    PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    JwtTokenProvider tokenProvider =
            new JwtTokenProvider("test-secret-key-that-is-at-least-32-bytes-long!!", 604800000L);

    AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, tokenProvider);
    }

    @Test
    void registerHashesPasswordAndReturnsToken() {
        when(userRepository.existsByEmail("abe@example.com")).thenReturn(false);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            ReflectionTestUtils.setField(u, "id", UUID.randomUUID());
            return u;
        });

        AuthResponse resp = authService.register(
                new RegisterRequest("Abebe", "abe@example.com", "password1"));

        assertThat(resp.token()).isNotBlank();
        assertThat(resp.role()).isEqualTo("PATIENT");

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());
        assertThat(captor.getValue().getPasswordHash()).isNotEqualTo("password1");
        assertThat(passwordEncoder.matches("password1", captor.getValue().getPasswordHash())).isTrue();
    }

    @Test
    void registerRejectsDuplicateEmail() {
        when(userRepository.existsByEmail("abe@example.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(
                new RegisterRequest("Abebe", "abe@example.com", "password1")))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void loginFailsWithWrongPassword() {
        User user = new User("abe@example.com", passwordEncoder.encode("password1"), "Abebe");
        ReflectionTestUtils.setField(user, "id", UUID.randomUUID());
        when(userRepository.findByEmail("abe@example.com")).thenReturn(Optional.of(user));

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("abe@example.com", "wrongpass")))
                .isInstanceOf(UnauthorizedException.class);
    }

    @Test
    void loginSucceedsWithCorrectPassword() {
        User user = new User("abe@example.com", passwordEncoder.encode("password1"), "Abebe");
        ReflectionTestUtils.setField(user, "id", UUID.randomUUID());
        when(userRepository.findByEmail("abe@example.com")).thenReturn(Optional.of(user));

        AuthResponse resp = authService.login(new LoginRequest("abe@example.com", "password1"));

        assertThat(resp.token()).isNotBlank();
        assertThat(resp.userId()).isEqualTo(user.getId().toString());
    }
}
