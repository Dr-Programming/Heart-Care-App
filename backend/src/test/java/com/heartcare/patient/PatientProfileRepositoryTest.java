package com.heartcare.patient;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.patient.model.Goals;
import com.heartcare.patient.model.PatientProfile;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class PatientProfileRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    PatientProfileRepository repository;

    @Autowired
    JdbcTemplate jdbcTemplate;

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, id + "@example.com", "x", "Test User");
        return id;
    }

    @Test
    void savesAndReloadsJsonbFields() {
        UUID userId = seedUser();
        PatientProfile profile = new PatientProfile(userId);
        profile.setBirthYear(1975);
        profile.setPreferredLanguage("am");
        profile.setHeightCm(172);
        profile.setComorbidities(List.of("diabetes", "hypertension"));
        profile.setGoals(new Goals(120, 80, 180, 8000, 70, "low salt"));

        repository.saveAndFlush(profile);

        PatientProfile reloaded = repository.findById(userId).orElseThrow();
        assertThat(reloaded.getComorbidities()).containsExactly("diabetes", "hypertension");
        assertThat(reloaded.getGoals().stepsPerDay()).isEqualTo(8000);
        assertThat(reloaded.getGoals().dietNote()).isEqualTo("low salt");
        assertThat(reloaded.getPreferredLanguage()).isEqualTo("am");
    }
}
