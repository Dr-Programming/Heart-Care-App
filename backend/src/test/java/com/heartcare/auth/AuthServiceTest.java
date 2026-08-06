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

    static final String PHONE = "+251911234567";

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

    private User existingUser(String pin) {
        User user = new User(PHONE, passwordEncoder.encode(pin), "Abebe Girma", "am");
        ReflectionTestUtils.setField(user, "id", UUID.randomUUID());
        return user;
    }

    @Test
    void registerHashesPinAndReturnsTokenWithUser() {
        when(userRepository.existsByPhone(PHONE)).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            ReflectionTestUtils.setField(u, "id", UUID.randomUUID());
            return u;
        });

        AuthResponse resp = authService.register(
                new RegisterRequest(PHONE, "1234", "Abebe Girma", "am"));

        assertThat(resp.token()).isNotBlank();
        assertThat(resp.user().phone()).isEqualTo(PHONE);
        assertThat(resp.user().name()).isEqualTo("Abebe Girma");
        assertThat(resp.user().preferredLanguage()).isEqualTo("am");
        assertThat(resp.user().role()).isEqualTo("PATIENT");
        assertThat(resp.user().id()).isNotBlank();

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).saveAndFlush(captor.capture());
        assertThat(captor.getValue().getPinHash()).isNotEqualTo("1234");
        assertThat(passwordEncoder.matches("1234", captor.getValue().getPinHash())).isTrue();
    }

    @Test
    void registerRejectsDuplicatePhone() {
        when(userRepository.existsByPhone(PHONE)).thenReturn(true);

        assertThatThrownBy(() -> authService.register(
                new RegisterRequest(PHONE, "1234", "Abebe Girma", "en")))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void registerTranslatesDbUniqueViolationToConflict() {
        when(userRepository.existsByPhone(PHONE)).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class)))
                .thenThrow(new org.springframework.dao.DataIntegrityViolationException("duplicate phone"));

        assertThatThrownBy(() -> authService.register(
                new RegisterRequest(PHONE, "1234", "Abebe Girma", "en")))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void loginSucceedsWithCorrectPin() {
        User user = existingUser("1234");
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        AuthResponse resp = authService.login(new LoginRequest(PHONE, "1234"));

        assertThat(resp.token()).isNotBlank();
        assertThat(resp.user().id()).isEqualTo(user.getId().toString());
    }

    @Test
    void loginFailsWithWrongPin() {
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(existingUser("1234")));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PHONE, "9999")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage("Invalid phone or PIN");
    }

    @Test
    void loginWithUnknownPhoneGivesTheSameMessageAsAWrongPin() {
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(new LoginRequest(PHONE, "1234")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage("Invalid phone or PIN");
    }

    @Test
    void getCurrentUserReturnsUserResponse() {
        User user = existingUser("1234");
        UUID id = user.getId();
        when(userRepository.findById(id)).thenReturn(Optional.of(user));

        UserResponse resp = authService.getCurrentUser(id);

        assertThat(resp.id()).isEqualTo(id.toString());
        assertThat(resp.phone()).isEqualTo(PHONE);
        assertThat(resp.name()).isEqualTo("Abebe Girma");
        assertThat(resp.preferredLanguage()).isEqualTo("am");
        assertThat(resp.role()).isEqualTo("PATIENT");
    }

    @Test
    void getCurrentUserThrowsWhenAbsent() {
        UUID id = UUID.randomUUID();
        when(userRepository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.getCurrentUser(id))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
