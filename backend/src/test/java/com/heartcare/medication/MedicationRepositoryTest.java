package com.heartcare.medication;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.medication.model.DoseLog;
import com.heartcare.medication.model.DoseStatus;
import com.heartcare.medication.model.Frequency;
import com.heartcare.medication.model.Medication;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class MedicationRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    MedicationRepository medicationRepository;

    @Autowired
    DoseLogRepository doseLogRepository;

    @Autowired
    JdbcTemplate jdbcTemplate;

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, phone, pin_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, TestUsers.nextPhone(), "x", "Test User");
        return id;
    }

    @Test
    void savesAndReloadsMedicationWithJsonbSchedule() {
        UUID userId = seedUser();
        Medication med = new Medication();
        med.setUserId(userId);
        med.setName("Aspirin");
        med.setDoseMg(new BigDecimal("100.00"));
        med.setFrequency(Frequency.BID);
        med.setScheduleTimes(List.of("08:00", "20:00"));

        Medication saved = medicationRepository.saveAndFlush(med);

        Medication reloaded = medicationRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getName()).isEqualTo("Aspirin");
        assertThat(reloaded.getFrequency()).isEqualTo(Frequency.BID);
        assertThat(reloaded.getScheduleTimes()).containsExactly("08:00", "20:00");
        assertThat(reloaded.isActive()).isTrue();
        assertThat(reloaded.getDoseMg()).isEqualByComparingTo("100.00");
    }

    @Test
    void savesDoseLogReferencingMedication() {
        UUID userId = seedUser();
        Medication med = new Medication();
        med.setUserId(userId);
        med.setName("Atorvastatin");
        med.setDoseMg(new BigDecimal("20.00"));
        med.setFrequency(Frequency.ONCE_DAILY);
        med.setScheduleTimes(List.of("21:00"));
        Medication savedMed = medicationRepository.saveAndFlush(med);

        DoseLog dose = new DoseLog();
        dose.setMedicationId(savedMed.getId());
        dose.setUserId(userId);
        dose.setScheduledDate(LocalDate.of(2026, 7, 10));
        dose.setScheduledTime(LocalTime.of(21, 0));
        dose.setStatus(DoseStatus.TAKEN);
        dose.setLoggedAt(OffsetDateTime.now());
        dose.setNote("took with food");

        DoseLog savedDose = doseLogRepository.saveAndFlush(dose);

        DoseLog reloaded = doseLogRepository.findById(savedDose.getId()).orElseThrow();
        assertThat(reloaded.getStatus()).isEqualTo(DoseStatus.TAKEN);
        assertThat(reloaded.getScheduledTime()).isEqualTo(LocalTime.of(21, 0));
        assertThat(reloaded.getNote()).isEqualTo("took with food");
        assertThat(reloaded.getMedicationId()).isEqualTo(savedMed.getId());
    }
}
