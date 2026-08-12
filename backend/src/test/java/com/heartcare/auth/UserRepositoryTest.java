package com.heartcare.auth;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.auth.model.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

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

    // The two tests below are the ONLY place the lockout SQL meets a real database. AuthServiceTest
    // covers the same methods against a Mockito mock, where both are no-ops that record a call — so
    // it asserts that the service asks for the write, never that the write does anything. Without
    // these, dropping `locked_until = NULL` from resetFailedAttempts, or inverting the CASE in
    // recordFailedAttempt, would leave the entire suite green.

    @Test
    void recordFailedAttemptIncrementsAndStampsTheLockOnlyOnTheAttemptThatReachesTheLimit() {
        User user = userRepository.saveAndFlush(new User("+251955555555", "h", "L", "en"));
        UUID id = user.getId();
        OffsetDateTime lockUntil = OffsetDateTime.now().plusMinutes(15);

        for (int attempt = 1; attempt < 5; attempt++) {
            userRepository.recordFailedAttempt(id, 5, lockUntil);

            User reread = userRepository.findById(id).orElseThrow();
            assertThat(reread.getFailedLoginAttempts()).isEqualTo(attempt);
            assertThat(reread.getLockedUntil())
                    .as("attempt %d is below the limit, so the account must stay unlocked", attempt)
                    .isNull();
        }

        userRepository.recordFailedAttempt(id, 5, lockUntil);

        User locked = userRepository.findById(id).orElseThrow();
        assertThat(locked.getFailedLoginAttempts()).isEqualTo(5);
        assertThat(locked.getLockedUntil()).isCloseTo(lockUntil, within(1, ChronoUnit.SECONDS));
    }

    @Test
    void resetFailedAttemptsClearsBothTheCounterAndTheLock() {
        User user = userRepository.saveAndFlush(new User("+251966666666", "h", "C", "en"));
        UUID id = user.getId();
        userRepository.recordFailedAttempt(id, 1, OffsetDateTime.now().plusMinutes(15));
        // Precondition: the row really is locked, so the assertions below cannot pass vacuously.
        assertThat(userRepository.findById(id).orElseThrow().getLockedUntil()).isNotNull();

        userRepository.resetFailedAttempts(id);

        User cleared = userRepository.findById(id).orElseThrow();
        assertThat(cleared.getFailedLoginAttempts()).isZero();
        assertThat(cleared.getLockedUntil())
                .as("clearing the counter but leaving locked_until set would lock the account "
                        + "forever — nothing else resets it")
                .isNull();
    }
}
