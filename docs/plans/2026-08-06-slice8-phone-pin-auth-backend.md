# Phone+PIN Auth (Backend Half) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the backend's email+password authentication with phone (`+251…`) + 4-digit PIN, and add per-account login lockout (closing SecurityReview M-1).

**Architecture:** A contained change to the `auth` package plus one Flyway migration. `users` loses `email`/`password_hash` and gains `phone` (unique), `pin_hash`, `preferred_language`, `failed_login_attempts`, `locked_until`. The three endpoints (`register`, `login`, `me`) keep their paths and the `ApiResponse` envelope; only the request/response bodies change. Lockout is an in-DB counter — no Redis, no new dependency. Every other feature package is untouched; the ripple is confined to test fixtures that seed users.

**Tech Stack:** Spring Boot 4.1 / Java 21 · Spring Security + BCrypt · Spring Data JPA (Hibernate 7, `ddl-auto=validate`) · Flyway · JUnit 5 + Mockito + AssertJ · Testcontainers (`postgres:16-alpine`) · Jackson 3 (`tools.jackson.*` at runtime; `@JsonIgnore` still comes from `com.fasterxml.jackson.annotation`).

## Global Constraints

- **Spec:** `docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md` §2 (backend half only — §3 frontend is a separate plan).
- **Branch:** `feature/phone-pin-auth` (already published, tracking `origin/feature/phone-pin-auth`). PR base is `dev`.
- **Commits:** no AI co-author trailer. Conventional-commit subjects.
- **Phone format:** `^\+251\d{9}$` — literal `+251` then exactly 9 digits (13 chars total).
- **PIN format:** `^\d{4}$` — exactly 4 digits. Stored **only** as a BCrypt hash, never logged.
- **Language codes:** `en` | `am` only.
- **Lockout:** 5 failed attempts → 15-minute lock; per-account; a successful login clears the counter. Values come from `application.yml` (`app.auth.lockout.max-attempts`, `app.auth.lockout.duration-minutes`), not literals in code.
- **Status codes:** this API uses **no `201`** — every success is `200` inside the `ApiResponse` envelope (documented in `backend/docs/API.md` §Error handling). The spec's §2.1 sketch shows `201` for register; **we deliberately keep `200`** for consistency with every other create endpoint in the API. New code: `423 Locked` for an active lockout.
- **Generic login failure:** the message for unknown-phone and wrong-PIN must be byte-identical (`"Invalid phone or PIN"`) so login cannot enumerate accounts. Registration may still reveal a duplicate (409) — this asymmetry is pre-existing and documented.
- **No `email` or `password` string may remain** anywhere under `backend/src` when the plan is done (grep is part of Task 4's verification).
- **Docker must be running** for any integration test (`AbstractIntegrationTest` starts a Testcontainer).
- Run all Maven commands from `P:\Heart-Care-App\backend`.

---

## File Structure

**Created**
- `backend/src/main/resources/db/migration/V8__phone_pin_auth.sql` — the schema swap.
- `backend/src/main/java/com/heartcare/common/exception/AccountLockedException.java` — maps to `423`.
- `backend/src/test/java/com/heartcare/TestUsers.java` — shared, collision-free phone generator for test fixtures.
- `backend/src/test/java/com/heartcare/auth/AuthDtoValidationTest.java` — pure-unit validation of the phone/PIN/language patterns.

**Modified**
- `auth/model/User.java` — field swap + lockout fields.
- `auth/UserRepository.java` — `findByPhone`/`existsByPhone`; lockout update queries (Task 3).
- `auth/dto/RegisterRequest.java`, `LoginRequest.java`, `AuthResponse.java`, `UserResponse.java` — new contract.
- `auth/AuthService.java` — register/login/me rewrite; lockout (Task 3).
- `common/exception/GlobalExceptionHandler.java` — `423` handler (Task 3).
- `src/main/resources/application.yml` — `app.auth.lockout.*` (Task 3).
- 3 auth test classes (Task 1) + 19 downstream test classes (Task 2).
- `backend/docs/API.md`, `backend/docs/SecurityReview.md`, `backend/README.md` (Task 4).

**Untouched by design:** `AuthController` keeps its method bodies (only DTO types flow through), `JwtTokenProvider`, `JwtAuthFilter`, `UserPrincipal`, `SecurityConfig` (register/login are already `permitAll`), and every non-auth feature package.

---

### Task 1: Schema, entity, and the phone+PIN contract (no lockout yet)

The entity, DTOs, service, and migration must land together — `ddl-auto=validate` means a migration that drops `email` while the entity still maps it fails every Spring context in the suite. Lockout is deliberately deferred to Task 3 so this task is a clean contract swap.

**Files:**
- Create: `backend/src/main/resources/db/migration/V8__phone_pin_auth.sql`
- Modify: `backend/src/main/java/com/heartcare/auth/model/User.java`
- Modify: `backend/src/main/java/com/heartcare/auth/UserRepository.java`
- Modify: `backend/src/main/java/com/heartcare/auth/dto/RegisterRequest.java`
- Modify: `backend/src/main/java/com/heartcare/auth/dto/LoginRequest.java`
- Modify: `backend/src/main/java/com/heartcare/auth/dto/AuthResponse.java`
- Modify: `backend/src/main/java/com/heartcare/auth/dto/UserResponse.java`
- Modify: `backend/src/main/java/com/heartcare/auth/AuthService.java`
- Test: `backend/src/test/java/com/heartcare/auth/AuthServiceTest.java` (rewrite)
- Test: `backend/src/test/java/com/heartcare/auth/UserRepositoryTest.java` (rewrite)
- Test: `backend/src/test/java/com/heartcare/auth/AuthControllerIntegrationTest.java` (rewrite)
- Test: `backend/src/test/java/com/heartcare/auth/AuthDtoValidationTest.java` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `User(String phone, String pinHash, String fullName, String preferredLanguage)`; getters `getId()`, `getPhone()`, `getPinHash()`, `getFullName()`, `getPreferredLanguage()`, `getRole()`, `getFailedLoginAttempts()`, `getLockedUntil()`.
  - `UserRepository.findByPhone(String) : Optional<User>`, `UserRepository.existsByPhone(String) : boolean`.
  - `RegisterRequest(String phone, String pin, String name, String preferredLanguage)`, `LoginRequest(String phone, String pin)`.
  - `UserResponse(String id, String name, String phone, String preferredLanguage, String role)`, `AuthResponse(String token, UserResponse user)`.
  - `AuthService(UserRepository, PasswordEncoder, JwtTokenProvider)` — a 3-arg constructor. **Task 3 replaces it with a 5-arg constructor.**

---

- [ ] **Step 1: Write the migration**

Create `backend/src/main/resources/db/migration/V8__phone_pin_auth.sql`:

```sql
-- Auth model change: email + password  ->  phone (+251XXXXXXXXX) + 4-digit PIN.
--
-- The app is pre-release and has no production users. Existing rows cannot be migrated
-- forward because no phone number was ever collected, and `phone` is UNIQUE NOT NULL, so
-- there is no backfill value that would satisfy the constraint. The table is therefore
-- emptied first. CASCADE clears the dependent log tables, every one of which declares
-- `user_id ... REFERENCES users(id) ON DELETE CASCADE`.
TRUNCATE TABLE users CASCADE;

ALTER TABLE users
    DROP COLUMN email,
    DROP COLUMN password_hash,
    ADD COLUMN phone                 VARCHAR(20)  NOT NULL,
    ADD COLUMN pin_hash              VARCHAR(255) NOT NULL,
    ADD COLUMN preferred_language    VARCHAR(2)   NOT NULL DEFAULT 'en',
    ADD COLUMN failed_login_attempts INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN locked_until          TIMESTAMPTZ;

ALTER TABLE users ADD CONSTRAINT users_phone_key UNIQUE (phone);
```

- [ ] **Step 2: Rewrite the `User` entity**

Replace the whole of `backend/src/main/java/com/heartcare/auth/model/User.java`:

```java
package com.heartcare.auth.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonIgnore;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true, length = 20)
    private String phone;

    @Column(name = "pin_hash", nullable = false)
    @JsonIgnore
    private String pinHash;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "preferred_language", nullable = false, length = 2)
    private String preferredLanguage = "en";

    @Column(nullable = false, length = 20)
    private String role = "PATIENT";

    /** Consecutive failed login attempts; reset to 0 by any successful login. */
    @Column(name = "failed_login_attempts", nullable = false)
    private int failedLoginAttempts;

    /** When non-null and in the future, login is refused with 423 without checking the PIN. */
    @Column(name = "locked_until")
    private OffsetDateTime lockedUntil;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected User() {
        // for JPA
    }

    public User(String phone, String pinHash, String fullName, String preferredLanguage) {
        this.phone = phone;
        this.pinHash = pinHash;
        this.fullName = fullName;
        this.preferredLanguage = preferredLanguage;
        this.role = "PATIENT";
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }

    public UUID getId() {
        return id;
    }

    public String getPhone() {
        return phone;
    }

    public String getPinHash() {
        return pinHash;
    }

    public String getFullName() {
        return fullName;
    }

    public String getPreferredLanguage() {
        return preferredLanguage;
    }

    public String getRole() {
        return role;
    }

    public int getFailedLoginAttempts() {
        return failedLoginAttempts;
    }

    public OffsetDateTime getLockedUntil() {
        return lockedUntil;
    }
}
```

- [ ] **Step 3: Rewrite `UserRepository`**

Replace `backend/src/main/java/com/heartcare/auth/UserRepository.java`:

```java
package com.heartcare.auth;

import com.heartcare.auth.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByPhone(String phone);

    boolean existsByPhone(String phone);
}
```

- [ ] **Step 4: Rewrite the DTOs**

`backend/src/main/java/com/heartcare/auth/dto/RegisterRequest.java`:

```java
package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Registration is identity only — phone, PIN, name, language. Medical onboarding is a
 * separate slice (patient profile), so nothing clinical is accepted here.
 */
public record RegisterRequest(
        @NotBlank
        @Pattern(regexp = "^\\+251\\d{9}$", message = "phone must be in +251XXXXXXXXX format")
        String phone,

        // A 4-digit PIN is 10,000 combinations, which is only defensible because login is
        // rate-limited by the account lockout. See AuthService.
        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "pin must be exactly 4 digits")
        String pin,

        @NotBlank
        @Size(max = 255, message = "name must be at most 255 characters")
        String name,

        @NotBlank
        @Pattern(regexp = "^(en|am)$", message = "preferredLanguage must be en or am")
        String preferredLanguage) {
}
```

`backend/src/main/java/com/heartcare/auth/dto/LoginRequest.java`:

```java
package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record LoginRequest(
        @NotBlank
        @Pattern(regexp = "^\\+251\\d{9}$", message = "phone must be in +251XXXXXXXXX format")
        String phone,

        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "pin must be exactly 4 digits")
        String pin) {
}
```

`backend/src/main/java/com/heartcare/auth/dto/UserResponse.java`:

```java
package com.heartcare.auth.dto;

/** The user as the mobile app caches it. Never carries the PIN hash. */
public record UserResponse(
        String id,
        String name,
        String phone,
        String preferredLanguage,
        String role) {
}
```

`backend/src/main/java/com/heartcare/auth/dto/AuthResponse.java`:

```java
package com.heartcare.auth.dto;

/**
 * Register and login both return the token plus the full user, so the client can seed its
 * offline cache in one round trip instead of following up with GET /auth/me.
 */
public record AuthResponse(String token, UserResponse user) {
}
```

- [ ] **Step 5: Write the failing service tests**

Replace `backend/src/test/java/com/heartcare/auth/AuthServiceTest.java`:

```java
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
```

- [ ] **Step 6: Run the service tests to verify they fail**

Run: `mvn test -Dtest=AuthServiceTest`
Expected: FAIL — compilation errors in `AuthService` (it still calls `request.email()` / `existsByEmail`).

- [ ] **Step 7: Rewrite `AuthService`**

Replace `backend/src/main/java/com/heartcare/auth/AuthService.java`:

```java
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
```

- [ ] **Step 8: Run the service tests to verify they pass**

Run: `mvn test -Dtest=AuthServiceTest`
Expected: PASS — 7 tests.

- [ ] **Step 9: Write the DTO validation test**

Create `backend/src/test/java/com/heartcare/auth/AuthDtoValidationTest.java`:

```java
package com.heartcare.auth;

import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.RegisterRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The phone and PIN patterns are the whole input contract for auth, so they are pinned here
 * as fast unit assertions rather than only through the (slow) integration test.
 */
class AuthDtoValidationTest {

    static final ValidatorFactory FACTORY = Validation.buildDefaultValidatorFactory();
    static final Validator VALIDATOR = FACTORY.getValidator();

    private RegisterRequest register(String phone, String pin, String name, String lang) {
        return new RegisterRequest(phone, pin, name, lang);
    }

    @Test
    void acceptsAWellFormedRegistration() {
        assertThat(VALIDATOR.validate(register("+251911234567", "1234", "Abebe", "am"))).isEmpty();
    }

    @Test
    void rejectsPhoneWithoutTheEthiopianPrefix() {
        assertThat(VALIDATOR.validate(register("0911234567", "1234", "Abebe", "en"))).isNotEmpty();
    }

    @Test
    void rejectsPhoneWithTheWrongNumberOfDigits() {
        assertThat(VALIDATOR.validate(register("+25191123456", "1234", "Abebe", "en"))).isNotEmpty();
        assertThat(VALIDATOR.validate(register("+2519112345678", "1234", "Abebe", "en"))).isNotEmpty();
    }

    @Test
    void rejectsPinThatIsNotExactlyFourDigits() {
        assertThat(VALIDATOR.validate(register("+251911234567", "123", "Abebe", "en"))).isNotEmpty();
        assertThat(VALIDATOR.validate(register("+251911234567", "12345", "Abebe", "en"))).isNotEmpty();
        assertThat(VALIDATOR.validate(register("+251911234567", "12a4", "Abebe", "en"))).isNotEmpty();
    }

    @Test
    void rejectsBlankName() {
        assertThat(VALIDATOR.validate(register("+251911234567", "1234", "  ", "en"))).isNotEmpty();
    }

    @Test
    void rejectsUnsupportedLanguage() {
        assertThat(VALIDATOR.validate(register("+251911234567", "1234", "Abebe", "fr"))).isNotEmpty();
    }

    @Test
    void loginRequestEnforcesTheSamePhoneAndPinRules() {
        assertThat(VALIDATOR.validate(new LoginRequest("+251911234567", "1234"))).isEmpty();
        assertThat(VALIDATOR.validate(new LoginRequest("0911234567", "1234"))).isNotEmpty();
        assertThat(VALIDATOR.validate(new LoginRequest("+251911234567", "abcd"))).isNotEmpty();
    }
}
```

- [ ] **Step 10: Run the validation test**

Run: `mvn test -Dtest=AuthDtoValidationTest`
Expected: PASS — 7 tests.

- [ ] **Step 11: Rewrite the repository test**

Replace `backend/src/test/java/com/heartcare/auth/UserRepositoryTest.java`:

```java
package com.heartcare.auth;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.auth.model.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Transactional
class UserRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    UserRepository userRepository;

    @Test
    void savesAndFindsByPhone() {
        userRepository.save(new User("+251911111111", "hash", "Abebe", "en"));

        assertThat(userRepository.findByPhone("+251911111111")).isPresent();
        assertThat(userRepository.existsByPhone("+251911111111")).isTrue();
        assertThat(userRepository.existsByPhone("+251922222222")).isFalse();
    }

    @Test
    void enforcesUniquePhone() {
        userRepository.saveAndFlush(new User("+251933333333", "h", "A", "en"));

        assertThatThrownBy(() ->
                userRepository.saveAndFlush(new User("+251933333333", "h", "B", "en")))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void assignsIdAndDefaultsForRoleAndLockoutFields() {
        User saved = userRepository.saveAndFlush(new User("+251944444444", "h", "R", "am"));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getRole()).isEqualTo("PATIENT");
        assertThat(saved.getPreferredLanguage()).isEqualTo("am");
        assertThat(saved.getFailedLoginAttempts()).isZero();
        assertThat(saved.getLockedUntil()).isNull();
    }
}
```

- [ ] **Step 12: Rewrite the auth integration test**

Replace `backend/src/test/java/com/heartcare/auth/AuthControllerIntegrationTest.java`:

```java
package com.heartcare.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.RegisterRequest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AuthControllerIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    WebApplicationContext wac;

    final ObjectMapper objectMapper = new ObjectMapper();

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    @Test
    void registerThenLoginThenMe() throws Exception {
        String phone = TestUsers.nextPhone();
        String registerBody = objectMapper.writeValueAsString(
                new RegisterRequest(phone, "1234", "Abebe Girma", "am"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(registerBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.token").exists())
                .andExpect(jsonPath("$.data.user.phone").value(phone))
                .andExpect(jsonPath("$.data.user.name").value("Abebe Girma"))
                .andExpect(jsonPath("$.data.user.preferredLanguage").value("am"))
                .andExpect(jsonPath("$.data.user.role").value("PATIENT"));

        String loginBody = objectMapper.writeValueAsString(new LoginRequest(phone, "1234"));

        MvcResult loginResult = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists())
                .andReturn();

        String token = JsonPath.read(loginResult.getResponse().getContentAsString(), "$.data.token");

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.phone").value(phone))
                .andExpect(jsonPath("$.data.name").value("Abebe Girma"))
                .andExpect(jsonPath("$.data.preferredLanguage").value("am"));
    }

    @Test
    void loginWithWrongPinReturns401() throws Exception {
        String phone = TestUsers.nextPhone();
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(phone, "1234", "Abebe", "en"))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(phone, "9999"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid phone or PIN"));
    }

    @Test
    void loginWithUnknownPhoneReturns401WithTheSameMessage() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new LoginRequest(TestUsers.nextPhone(), "1234"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid phone or PIN"));
    }

    @Test
    void meWithoutTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void meWithInvalidTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer not-a-real-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void duplicateRegisterReturns409() throws Exception {
        String body = objectMapper.writeValueAsString(
                new RegisterRequest(TestUsers.nextPhone(), "1234", "Abebe", "en"));

        mockMvc.perform(post("/api/v1/auth/register")
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value("Phone already registered"));
    }

    @Test
    void registerWithMalformedPhoneReturns400() throws Exception {
        String body = objectMapper.writeValueAsString(
                new RegisterRequest("0911234567", "1234", "Abebe", "en"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());
    }

    @Test
    void registerWithNonNumericPinReturns400() throws Exception {
        String body = objectMapper.writeValueAsString(
                new RegisterRequest(TestUsers.nextPhone(), "abcd", "Abebe", "en"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());
    }
}
```

- [ ] **Step 13: Create the shared test phone generator**

This class is used by the integration test above and by every fixture in Task 2. Create `backend/src/test/java/com/heartcare/TestUsers.java`:

```java
package com.heartcare;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Hands out unique, well-formed Ethiopian phone numbers for test fixtures.
 *
 * <p>`users.phone` is UNIQUE and the Testcontainer database is shared by every test class in
 * the JVM, so fixtures cannot hard-code a number or derive one per class — either would
 * collide across classes and fail intermittently. A single JVM-wide sequence cannot.
 */
public final class TestUsers {

    private static final AtomicLong SEQUENCE = new AtomicLong(910_000_000L);

    private TestUsers() {
    }

    /** e.g. {@code +251910000001} — matches the {@code ^\+251\d{9}$} contract. */
    public static String nextPhone() {
        return "+251" + SEQUENCE.incrementAndGet();
    }
}
```

- [ ] **Step 14: Run the auth tests end to end**

Run: `mvn test -Dtest='AuthServiceTest,AuthDtoValidationTest,UserRepositoryTest,AuthControllerIntegrationTest'`
Expected: PASS — all four classes green. (Docker must be running.)

If Flyway reports a checksum/validation error against a pre-existing local database, the dev DB predates `V8`; run `docker compose down -v && docker compose up -d` from the repo root and retry. Test containers are always fresh and unaffected.

- [ ] **Step 15: Commit**

```bash
git add backend/src/main/resources/db/migration/V8__phone_pin_auth.sql \
        backend/src/main/java/com/heartcare/auth \
        backend/src/test/java/com/heartcare/auth \
        backend/src/test/java/com/heartcare/TestUsers.java
git commit -m "feat(auth): replace email+password with phone and 4-digit PIN"
```

---

### Task 2: Repoint every downstream test fixture at phone+PIN

Task 1 leaves the main sources correct but 19 test classes still seed users the old way — some with a raw `INSERT` naming dropped columns, some by POSTing an email/password registration. They compile (the offending values are strings and JSON keys) but fail at runtime, so the suite is red until this task lands.

**Files:**
- Modify (raw `INSERT INTO users` seeds — 11 files):
  - `backend/src/test/java/com/heartcare/vitals/VitalsRepositoryTest.java`
  - `backend/src/test/java/com/heartcare/vitals/VitalsSyncHandlerTest.java`
  - `backend/src/test/java/com/heartcare/vitals/VitalsConcurrencyTest.java`
  - `backend/src/test/java/com/heartcare/patient/PatientProfileRepositoryTest.java`
  - `backend/src/test/java/com/heartcare/symptoms/SymptomsRepositoryTest.java`
  - `backend/src/test/java/com/heartcare/symptoms/SymptomsSyncHandlerTest.java`
  - `backend/src/test/java/com/heartcare/medication/MedicationRepositoryTest.java`
  - `backend/src/test/java/com/heartcare/medication/DoseLogSyncHandlerTest.java`
  - `backend/src/test/java/com/heartcare/activity/ActivityRepositoryTest.java`
  - `backend/src/test/java/com/heartcare/activity/ActivitySyncHandlerTest.java`
  - `backend/src/test/java/com/heartcare/sync/CreatePathConcurrencyTest.java`
- Modify (`registerAndGetToken()`-style helpers — 8 files):
  - `backend/src/test/java/com/heartcare/vitals/VitalsControllerIntegrationTest.java`
  - `backend/src/test/java/com/heartcare/patient/PatientControllerIntegrationTest.java`
  - `backend/src/test/java/com/heartcare/medication/MedicationControllerIntegrationTest.java`
  - `backend/src/test/java/com/heartcare/medication/DoseLogControllerIntegrationTest.java`
  - `backend/src/test/java/com/heartcare/symptoms/SymptomsControllerIntegrationTest.java`
  - `backend/src/test/java/com/heartcare/activity/ActivityControllerIntegrationTest.java`
  - `backend/src/test/java/com/heartcare/sync/SyncControllerIntegrationTest.java`
  - `backend/src/test/java/com/heartcare/common/RequestErrorMappingTest.java`

**Interfaces:**
- Consumes: `TestUsers.nextPhone()` (Task 1); the register contract `{phone, pin, name, preferredLanguage}` → `$.data.token`.
- Produces: a green suite for Task 3 to build on. No production interface.

---

- [ ] **Step 1: Confirm the suite is red for exactly the expected reason**

Run: `mvn test`
Expected: FAIL. Failures come only from the 19 classes listed above — raw-`INSERT` classes fail with a Postgres `column "email" of relation "users" does not exist`, register-helper classes fail because `status().isOk()` sees `400`. Auth classes from Task 1 pass. If anything else fails, stop and report it — the plan assumed a wrong blast radius.

- [ ] **Step 2: Fix the 11 raw-`INSERT` seed helpers**

In each of the 11 files, the seed is the same shape. Replace the column list and the email argument, leaving the rest of the method untouched. Before:

```java
    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, id + "@example.com", "x", "Test User");
        return id;
    }
```

After (add `import com.heartcare.TestUsers;`):

```java
    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, phone, pin_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, TestUsers.nextPhone(), "x", "Test User");
        return id;
    }
```

Notes:
- The method name, return type, and the display name argument (`"Test User"`, `"A"`, etc.) differ slightly between files — keep whatever each file already has. Only the SQL column list and the second bind value change.
- `pin_hash` is never verified by these tests (they never log in), so the placeholder `"x"` stays.
- `preferred_language`, `failed_login_attempts`, and `locked_until` all have DB defaults, so the `INSERT` does not list them.

- [ ] **Step 3: Fix the 8 registration helpers**

In each of the 8 files, replace the body-building block. Before:

```java
        ObjectNode body = objectMapper.createObjectNode();
        body.put("fullName", "Abebe");
        body.put("email", UUID.randomUUID() + "@example.com");
        body.put("password", "password1");
```

After (add `import com.heartcare.TestUsers;`):

```java
        ObjectNode body = objectMapper.createObjectNode();
        body.put("phone", TestUsers.nextPhone());
        body.put("pin", "1234");
        body.put("name", "Abebe");
        body.put("preferredLanguage", "en");
```

Notes:
- In `RequestErrorMappingTest` this block lives inline in `setUp()` rather than in a helper method — same replacement.
- Leave the surrounding `mockMvc.perform(...)`, `status().isOk()`, and `JsonPath.read(..., "$.data.token")` lines exactly as they are: register still returns `200` and the token is still at `$.data.token`.
- If a file no longer uses `java.util.UUID` after the change, remove the now-unused import; if it uses `UUID` elsewhere, keep it.

- [ ] **Step 4: Run the full suite**

Run: `mvn test`
Expected: PASS — every test green (~222 + the 7 new DTO validation tests, minus none; the exact count is whatever `mvn test` reports, and it must show `Failures: 0, Errors: 0`).

- [ ] **Step 5: Verify no email/password auth remnants survive in tests**

Run: `grep -rn "password_hash\|\"email\"\|\"password\"\|fullName\", \"" backend/src/test --include=*.java`
Expected: no hits. (`full_name` as a SQL column and `getFullName()` on the entity are correct and will not match this pattern.)

- [ ] **Step 6: Commit**

```bash
git add backend/src/test
git commit -m "test: seed fixtures with phone+PIN users"
```

---

### Task 3: Login lockout (SecurityReview M-1)

A 4-digit PIN is 10,000 combinations — trivially brute-forceable without a limit, which is exactly why M-1 was left open until the auth model was decided. Five consecutive failures lock the account for fifteen minutes.

**Files:**
- Create: `backend/src/main/java/com/heartcare/common/exception/AccountLockedException.java`
- Modify: `backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java`
- Modify: `backend/src/main/java/com/heartcare/auth/UserRepository.java`
- Modify: `backend/src/main/java/com/heartcare/auth/AuthService.java`
- Modify: `backend/src/main/resources/application.yml`
- Test: `backend/src/test/java/com/heartcare/auth/AuthServiceTest.java` (add lockout tests)
- Test: `backend/src/test/java/com/heartcare/auth/AuthControllerIntegrationTest.java` (add end-to-end lockout test)

**Interfaces:**
- Consumes: `User.getFailedLoginAttempts()`, `User.getLockedUntil()`, `AuthService.INVALID_CREDENTIALS` (Task 1); `TestUsers.nextPhone()`.
- Produces:
  - `AccountLockedException(String message) extends RuntimeException` → `423 Locked`.
  - `UserRepository.recordFailedAttempt(UUID id, int maxAttempts, OffsetDateTime lockUntil) : void`
  - `UserRepository.resetFailedAttempts(UUID id) : void`
  - `AuthService(UserRepository, PasswordEncoder, JwtTokenProvider, int maxAttempts, int lockoutMinutes)` — **replaces** the 3-arg constructor from Task 1.

---

- [ ] **Step 1: Write the failing lockout tests**

Append these to `backend/src/test/java/com/heartcare/auth/AuthServiceTest.java`, and change `setUp()` to use the new constructor:

```java
    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, tokenProvider, 5, 15);
    }
```

Add these imports to the class: `java.time.OffsetDateTime`, `com.heartcare.common.exception.AccountLockedException`, `static org.mockito.Mockito.never`, `static org.mockito.ArgumentMatchers.eq`, `static org.mockito.ArgumentMatchers.anyInt`. (`any` and `verify` are already imported from Task 1.)

```java
    @Test
    void aFailedLoginIsRecordedAgainstTheAccount() {
        User user = existingUser("1234");
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PHONE, "9999")))
                .isInstanceOf(UnauthorizedException.class);

        verify(userRepository).recordFailedAttempt(eq(user.getId()), eq(5), any(OffsetDateTime.class));
    }

    @Test
    void theFifthConsecutiveFailureLocksTheAccount() {
        User user = existingUser("1234");
        ReflectionTestUtils.setField(user, "failedLoginAttempts", 4);
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PHONE, "9999")))
                .isInstanceOf(AccountLockedException.class)
                .hasMessageContaining("15 minute");

        verify(userRepository).recordFailedAttempt(eq(user.getId()), eq(5), any(OffsetDateTime.class));
    }

    @Test
    void loginIsRefusedWhileTheLockIsActiveWithoutCheckingThePin() {
        User user = existingUser("1234");
        ReflectionTestUtils.setField(user, "failedLoginAttempts", 5);
        ReflectionTestUtils.setField(user, "lockedUntil", OffsetDateTime.now().plusMinutes(9));
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        // Even the CORRECT pin is refused while locked — that is what makes the lock a limit.
        assertThatThrownBy(() -> authService.login(new LoginRequest(PHONE, "1234")))
                .isInstanceOf(AccountLockedException.class)
                .hasMessageContaining("9 minute");

        verify(userRepository, never()).recordFailedAttempt(any(), anyInt(), any());
    }

    @Test
    void anExpiredLockLetsTheUserBackInAndClearsTheCounter() {
        User user = existingUser("1234");
        ReflectionTestUtils.setField(user, "failedLoginAttempts", 5);
        ReflectionTestUtils.setField(user, "lockedUntil", OffsetDateTime.now().minusSeconds(1));
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        AuthResponse resp = authService.login(new LoginRequest(PHONE, "1234"));

        assertThat(resp.token()).isNotBlank();
        verify(userRepository).resetFailedAttempts(user.getId());
    }

    @Test
    void aFailureAfterAnExpiredLockDoesNotImmediatelyRelock() {
        User user = existingUser("1234");
        ReflectionTestUtils.setField(user, "failedLoginAttempts", 5);
        ReflectionTestUtils.setField(user, "lockedUntil", OffsetDateTime.now().minusSeconds(1));
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        // The elapsed lock cleared the counter, so this is failure #1 of the next window,
        // not #6 of the last one.
        assertThatThrownBy(() -> authService.login(new LoginRequest(PHONE, "9999")))
                .isInstanceOf(UnauthorizedException.class);

        verify(userRepository).resetFailedAttempts(user.getId());
        verify(userRepository).recordFailedAttempt(eq(user.getId()), eq(5), any(OffsetDateTime.class));
    }

    @Test
    void aSuccessfulLoginClearsAPartialFailureStreak() {
        User user = existingUser("1234");
        ReflectionTestUtils.setField(user, "failedLoginAttempts", 3);
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        authService.login(new LoginRequest(PHONE, "1234"));

        verify(userRepository).resetFailedAttempts(user.getId());
    }

    @Test
    void aCleanSuccessfulLoginWritesNothing() {
        User user = existingUser("1234");
        when(userRepository.findByPhone(PHONE)).thenReturn(Optional.of(user));

        authService.login(new LoginRequest(PHONE, "1234"));

        verify(userRepository, never()).resetFailedAttempts(any());
        verify(userRepository, never()).recordFailedAttempt(any(), anyInt(), any());
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mvn test -Dtest=AuthServiceTest`
Expected: FAIL — compilation errors (`AccountLockedException` missing, no 5-arg constructor, no `recordFailedAttempt`/`resetFailedAttempts`).

- [ ] **Step 3: Add the exception and its 423 mapping**

Create `backend/src/main/java/com/heartcare/common/exception/AccountLockedException.java`:

```java
package com.heartcare.common.exception;

/**
 * Login refused because the account is inside its lockout window. Distinct from
 * {@link UnauthorizedException} so the client can say "try again in N minutes" instead of
 * "wrong PIN" — the user's PIN may well be right.
 */
public class AccountLockedException extends RuntimeException {

    public AccountLockedException(String message) {
        super(message);
    }
}
```

Add to `backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java`, directly after `handleUnauthorized`:

```java
    /**
     * 423 rather than 401: the credentials were never evaluated. A 401 would tell the client to
     * re-prompt for the PIN, which is exactly the retry the lockout exists to stop.
     */
    @ExceptionHandler(AccountLockedException.class)
    public ResponseEntity<ApiResponse<Void>> handleAccountLocked(AccountLockedException ex) {
        return ResponseEntity.status(HttpStatus.LOCKED).body(ApiResponse.error(ex.getMessage()));
    }
```

- [ ] **Step 4: Add the atomic lockout queries to `UserRepository`**

Replace `backend/src/main/java/com/heartcare/auth/UserRepository.java`:

```java
package com.heartcare.auth;

import com.heartcare.auth.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByPhone(String phone);

    boolean existsByPhone(String phone);

    /**
     * Increments the failure counter and, on the attempt that reaches the limit, stamps the
     * lock — in one statement. A read-modify-write in Java would lose increments under the
     * parallel guessing this is meant to stop (Postgres defaults to READ COMMITTED).
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = """
            UPDATE users
               SET failed_login_attempts = failed_login_attempts + 1,
                   locked_until = CASE WHEN failed_login_attempts + 1 >= :maxAttempts
                                       THEN :lockUntil
                                       ELSE locked_until END
             WHERE id = :id
            """, nativeQuery = true)
    void recordFailedAttempt(@Param("id") UUID id,
                             @Param("maxAttempts") int maxAttempts,
                             @Param("lockUntil") OffsetDateTime lockUntil);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = "UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE id = :id",
            nativeQuery = true)
    void resetFailedAttempts(@Param("id") UUID id);
}
```

- [ ] **Step 5: Add the lockout config**

In `backend/src/main/resources/application.yml`, extend the `app:` block (leave `jwt`, `cors`, and `sync` as they are):

```yaml
app:
  auth:
    lockout:
      # A 4-digit PIN is 10,000 combinations. Five tries per 15 minutes puts an exhaustive
      # search out of reach without punishing a patient who mistypes.
      max-attempts: 5
      duration-minutes: 15
```

- [ ] **Step 6: Implement lockout in `AuthService`**

In `backend/src/main/java/com/heartcare/auth/AuthService.java`, add imports `com.heartcare.common.exception.AccountLockedException`, `org.springframework.beans.factory.annotation.Value`, `java.time.Duration`, `java.time.OffsetDateTime`; replace the constructor and the `login` method:

```java
    private final int maxAttempts;
    private final int lockoutMinutes;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider tokenProvider,
                       @Value("${app.auth.lockout.max-attempts}") int maxAttempts,
                       @Value("${app.auth.lockout.duration-minutes}") int lockoutMinutes) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.maxAttempts = maxAttempts;
        this.lockoutMinutes = lockoutMinutes;
    }

    /**
     * noRollbackFor is load-bearing, not defensive: the failure counter is written and then the
     * request is rejected by throwing. Without it Spring rolls the increment back with the
     * exception and the account never locks.
     */
    @Transactional(noRollbackFor = {UnauthorizedException.class, AccountLockedException.class})
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByPhone(request.phone())
                .orElseThrow(() -> new UnauthorizedException(INVALID_CREDENTIALS));

        OffsetDateTime now = OffsetDateTime.now();
        int priorAttempts = user.getFailedLoginAttempts();
        boolean counterAlreadyCleared = false;

        if (user.getLockedUntil() != null) {
            if (user.getLockedUntil().isAfter(now)) {
                throw new AccountLockedException(lockedMessage(user.getLockedUntil(), now));
            }
            // The window elapsed: this attempt starts a fresh streak, otherwise the next single
            // mistake would re-lock the account immediately.
            userRepository.resetFailedAttempts(user.getId());
            priorAttempts = 0;
            counterAlreadyCleared = true;
        }

        if (!passwordEncoder.matches(request.pin(), user.getPinHash())) {
            OffsetDateTime lockUntil = now.plusMinutes(lockoutMinutes);
            userRepository.recordFailedAttempt(user.getId(), maxAttempts, lockUntil);
            if (priorAttempts + 1 >= maxAttempts) {
                throw new AccountLockedException(lockedMessage(lockUntil, now));
            }
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }

        if (priorAttempts > 0 && !counterAlreadyCleared) {
            userRepository.resetFailedAttempts(user.getId());
        }
        return authResponseFor(user);
    }

    private String lockedMessage(OffsetDateTime lockedUntil, OffsetDateTime now) {
        long minutes = Math.max(1,
                (long) Math.ceil(Duration.between(now, lockedUntil).toSeconds() / 60.0));
        return "Too many failed attempts. Try again in " + minutes
                + (minutes == 1 ? " minute." : " minutes.");
    }
```

- [ ] **Step 7: Run the service tests to verify they pass**

Run: `mvn test -Dtest=AuthServiceTest`
Expected: PASS — 14 tests.

- [ ] **Step 8: Add the end-to-end lockout test**

Append to `backend/src/test/java/com/heartcare/auth/AuthControllerIntegrationTest.java`:

```java
    @Test
    void fiveWrongPinsLockTheAccountAndTheCorrectPinIsThenRefused() throws Exception {
        String phone = TestUsers.nextPhone();
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(phone, "1234", "Abebe", "en"))))
                .andExpect(status().isOk());

        String wrongPin = objectMapper.writeValueAsString(new LoginRequest(phone, "9999"));

        for (int attempt = 1; attempt <= 4; attempt++) {
            mockMvc.perform(post("/api/v1/auth/login")
                            .contentType(APPLICATION_JSON).content(wrongPin))
                    .andExpect(status().isUnauthorized());
        }

        // The fifth failure trips the lock, and says so rather than repeating "invalid".
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON).content(wrongPin))
                .andExpect(status().isLocked())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString("Too many failed attempts")));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(phone, "1234"))))
                .andExpect(status().isLocked());
    }

    @Test
    void aSuccessfulLoginClearsTheFailureStreak() throws Exception {
        String phone = TestUsers.nextPhone();
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(phone, "1234", "Abebe", "en"))))
                .andExpect(status().isOk());

        String wrongPin = objectMapper.writeValueAsString(new LoginRequest(phone, "9999"));
        String rightPin = objectMapper.writeValueAsString(new LoginRequest(phone, "1234"));

        for (int attempt = 1; attempt <= 4; attempt++) {
            mockMvc.perform(post("/api/v1/auth/login")
                            .contentType(APPLICATION_JSON).content(wrongPin))
                    .andExpect(status().isUnauthorized());
        }

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON).content(rightPin))
                .andExpect(status().isOk());

        // Streak cleared: four more failures must not lock, because the counter restarted.
        for (int attempt = 1; attempt <= 4; attempt++) {
            mockMvc.perform(post("/api/v1/auth/login")
                            .contentType(APPLICATION_JSON).content(wrongPin))
                    .andExpect(status().isUnauthorized());
        }
    }
```

- [ ] **Step 9: Run the full suite**

Run: `mvn test`
Expected: PASS — `Failures: 0, Errors: 0`.

- [ ] **Step 10: Commit**

```bash
git add backend/src/main backend/src/test/java/com/heartcare/auth
git commit -m "feat(auth): lock accounts for 15 minutes after 5 failed PIN attempts"
```

---

### Task 4: Documentation

The API reference is the contract the Flutter half will be written against, so it has to describe phone+PIN before frontend work starts. `SecurityReview.md` has carried M-1 as the last open blocker; this closes it.

**Files:**
- Modify: `backend/docs/API.md`
- Modify: `backend/docs/SecurityReview.md`
- Modify: `backend/README.md`

**Interfaces:**
- Consumes: the finished contract from Tasks 1 and 3.
- Produces: no code interface — this is the reference the frontend plan reads.

---

- [ ] **Step 1: Rewrite the Auth section of `backend/docs/API.md`**

Replace the whole of `## 1. Auth` (from `### POST /api/v1/auth/register — public` through the `---` that precedes `## 2. Patient Profile`) with:

````markdown
### `POST /api/v1/auth/register` — public

Registers a patient and returns a token plus the user (auto-login). Role is always `PATIENT`; it
cannot be set by the client. Registration is identity only — medical details are set later through
`PUT /api/v1/patients/me`.

**Request**

```json
{
  "phone": "+251911234567",
  "pin": "1234",
  "name": "Abebe Bekele",
  "preferredLanguage": "am"
}
```

| Field | Type | Required | Rules |
|---|---|---|---|
| `phone` | string | ✅ | `+251` followed by exactly 9 digits |
| `pin` | string | ✅ | Exactly 4 digits |
| `name` | string | ✅ | Not blank, ≤ 255 characters |
| `preferredLanguage` | string | ✅ | `en` or `am` |

> The PIN is stored only as a BCrypt hash and is never returned or logged. Four digits is
> defensible only because login is lockout-limited — see below.

**Response** `200 OK`

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": "3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b",
      "name": "Abebe Bekele",
      "phone": "+251911234567",
      "preferredLanguage": "am",
      "role": "PATIENT"
    }
  },
  "message": "Registered",
  "timestamp": "2026-08-06T10:00:00Z"
}
```

**Errors**

| Code | Cause |
|---|---|
| `400` | Malformed phone, PIN that is not exactly 4 digits, blank name, unsupported language |
| `409` | `"Phone already registered"` |

> Registration reveals whether a phone is already in use. Login deliberately does not.

---

### `POST /api/v1/auth/login` — public

**Request**

```json
{ "phone": "+251911234567", "pin": "1234" }
```

**Response** `200 OK` — same `data` shape as register; `message` is `"Logged in"`.

**Errors**

| Code | Cause |
|---|---|
| `400` | Malformed phone or PIN |
| `401` | `"Invalid phone or PIN"` |
| `423` | `"Too many failed attempts. Try again in N minutes."` |

> The `401` message is identical for an unknown phone and a wrong PIN, so login cannot be used to
> enumerate accounts.

**Lockout.** Five consecutive failed attempts lock that account for 15 minutes. While locked, every
login returns `423` — including one with the correct PIN, which is what makes the limit real. Any
successful login resets the counter, and the counter also resets once the window elapses. The limit
is per account, held in the `users` row; there is no IP-based or global rate limit.

Clients must treat `423` as "wait", not "wrong PIN": re-prompting immediately just burns the
window. The message carries the remaining minutes.

---

### `GET /api/v1/auth/me` — authenticated

Returns the current user.

**Response** `200 OK`

```json
{
  "success": true,
  "data": {
    "id": "3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b",
    "name": "Abebe Bekele",
    "phone": "+251911234567",
    "preferredLanguage": "am",
    "role": "PATIENT"
  },
  "message": "OK",
  "timestamp": "2026-08-06T10:00:00Z"
}
```

**Errors:** `401` missing/invalid/expired token · `404` user no longer exists (deleted account with
a still-valid token).
````

- [ ] **Step 2: Update the status-code tables in `backend/docs/API.md`**

In `## Error handling → ### Status codes`:
- Change the `409 Conflict` row's "When" cell from `Registering an email that already exists` to `Registering a phone that already exists`.
- Insert a row directly after `413 Payload Too Large`:

```markdown
| `423 Locked` | Account locked | Five consecutive failed logins; the account is unavailable for 15 minutes |
```

In `### Retry semantics`, replace the first sentence so `423` is classified:

```markdown
`400`, `404`, `405`, `409`, and `413` are **permanent** — the request can never succeed as written,
so a client must not retry it. `401` is permanent until re-authentication. `423` is temporary but
must not be retried on a timer — it clears only after the 15-minute lockout window. Only `500` is
transient and worth retrying.
```

- [ ] **Step 3: Close M-1 in `backend/docs/SecurityReview.md`**

- Change the `### M-1` heading from `⚠️ OPEN (needs your call)` to `✅ FIXED (2026-08-06)`.
- Append to that section:

```markdown
**Fixed 2026-08-06** (`feature/phone-pin-auth`). Per-account lockout held in `users`
(`failed_login_attempts`, `locked_until`): 5 consecutive failures → 15 minutes, cleared by any
successful login or by the window elapsing. Configured at `app.auth.lockout.*`. The counter is
incremented by a single atomic `UPDATE` so parallel guessing cannot lose increments, and
`login` is annotated `noRollbackFor` so the rejection does not roll the increment back. No new
dependency (no bucket4j, no Redis). Locked logins return `423`.

This is per-account, not per-IP: it stops PIN guessing against a known phone number, which is the
threat a 4-digit PIN creates. A distributed attack spraying one PIN across many accounts is not
covered and needs an edge/gateway rule.
```

- In the header line near the top (`**Remediation pass:** 2026-07-19 …`), change `M-1 and M-2 remain open pending a decision, and are the only items now blocking a production deploy.` to `M-1 was fixed on 2026-08-06 alongside the phone+PIN auth change; M-2 (token revocation) remains open and is the only item now blocking a production deploy.`
- In the numbered "next steps" list at the end, remove the `M-1 — login rate limiting` item and renumber the remaining entries.

- [ ] **Step 4: Update the Build Progress table in `backend/README.md`**

Add a row to the Build Progress table recording this slice (match the existing row format exactly — read the table first):

```markdown
| 8 | Phone+PIN auth rework | ✅ | `V8` | Replaces email+password; adds 5-try/15-min account lockout (closes SecurityReview M-1) |
```

Also update any prose in that README that still describes registration as email+password.

- [ ] **Step 5: Verify no email/password auth remnants survive anywhere**

Run: `grep -rni "password" backend/src backend/docs/API.md`
Expected: only `PasswordEncoder` / `PasswordEncoderConfig` / `passwordEncoder` (the BCrypt bean, which is correctly named for its Spring type and still hashes the PIN) and any `password` mention in `SecurityReview.md` history. No `email` field, no `RegisterRequest.password`, no `"password"` JSON key.

Run: `grep -rn "email" backend/src backend/docs/API.md`
Expected: no hits.

- [ ] **Step 6: Run the full suite one last time**

Run: `mvn clean install`
Expected: BUILD SUCCESS, `Failures: 0, Errors: 0`.

- [ ] **Step 7: Commit**

```bash
git add backend/docs backend/README.md
git commit -m "docs(auth): document phone+PIN contract and close SecurityReview M-1"
```

---

## Definition of done (backend half)

- `V8` applies cleanly to a fresh database; `ddl-auto=validate` passes at context startup.
- `POST /auth/register`, `POST /auth/login`, `GET /auth/me` behave exactly as `backend/docs/API.md` §1 now describes, including `409`, `401`, and `423`.
- Five failed logins lock an account for 15 minutes; a success or an elapsed window clears it.
- `mvn clean install` is green with no `email`/`password_hash` references left under `backend/src`.
- `API.md`, `SecurityReview.md` (M-1 closed), and `backend/README.md` are updated.
- The frontend half (`docs/design/…` §3) can now be planned against a real, tested contract.

## Deliberate deviations from the spec

1. **Register returns `200`, not the `201` sketched in spec §2.1.** `API.md` states the API uses no `201` anywhere; a lone `201` on register would contradict every other create endpoint. Recorded here so the frontend plan expects `200`.
2. **`V8` truncates `users` (cascading to all log tables).** The spec's "no prod data" note makes this safe, but it is destructive to any local or Railway dev data. There is no alternative: `phone` is `UNIQUE NOT NULL` with no backfill value available.
3. **Lockout returns `423` on the attempt that trips it**, not a `401` followed by `423` only on the next try — the user learns immediately why retrying will not help.
