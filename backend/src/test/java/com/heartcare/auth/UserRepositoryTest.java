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
    void savesAndFindsByEmail() {
        userRepository.save(new User("abe@example.com", "hash", "Abebe"));

        assertThat(userRepository.findByEmail("abe@example.com")).isPresent();
        assertThat(userRepository.existsByEmail("abe@example.com")).isTrue();
        assertThat(userRepository.existsByEmail("nobody@example.com")).isFalse();
    }

    @Test
    void enforcesUniqueEmail() {
        userRepository.saveAndFlush(new User("dup@example.com", "h", "A"));

        assertThatThrownBy(() -> userRepository.saveAndFlush(new User("dup@example.com", "h", "B")))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void assignsIdAndDefaultRole() {
        User saved = userRepository.saveAndFlush(new User("role@example.com", "h", "R"));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getRole()).isEqualTo("PATIENT");
    }
}
