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
