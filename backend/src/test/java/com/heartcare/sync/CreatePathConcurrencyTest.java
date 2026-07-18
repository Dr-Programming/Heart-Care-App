package com.heartcare.sync;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.activity.ActivityService;
import com.heartcare.activity.dto.ActivityLogRequest;
import com.heartcare.medication.DoseLogService;
import com.heartcare.medication.MedicationService;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.model.DoseStatus;
import com.heartcare.medication.model.Frequency;
import com.heartcare.symptoms.SymptomsService;
import com.heartcare.symptoms.dto.SymptomLogRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;

/** The Task 1 race, proven closed on the four remaining create paths. */
class CreatePathConcurrencyTest extends AbstractIntegrationTest {

    @Autowired SymptomsService symptomsService;
    @Autowired ActivityService activityService;
    @Autowired MedicationService medicationService;
    @Autowired DoseLogService doseLogService;
    @Autowired JdbcTemplate jdbcTemplate;

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, id + "@example.com", "x", "Test User");
        return id;
    }

    /** Runs the same call on two threads released together; returns both ids. */
    private <T> void assertIdempotentUnderRace(Callable<String> call, String table, UUID userId, UUID crid)
            throws Exception {
        CountDownLatch gate = new CountDownLatch(1);
        Callable<String> gated = () -> { gate.await(); return call.call(); };
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<String> a = pool.submit(gated);
            Future<String> b = pool.submit(gated);
            gate.countDown();
            assertThat(a.get()).isEqualTo(b.get());
        } finally {
            pool.shutdownNow();
        }
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT id FROM " + table + " WHERE user_id = ? AND client_record_id = ?", userId, crid);
        assertThat(rows).hasSize(1);
    }

    @Test
    void symptomsLogIsIdempotentUnderRace() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        SymptomLogRequest request = new SymptomLogRequest(
                Map.of("chestPain", Map.of("present", false), "shortnessOfBreath", "NONE", "heartRate", 70,
                        "bloodPressure", Map.of("systolic", 120, "diastolic", 80), "swelling", false, "energyLevel", 8),
                OffsetDateTime.parse("2026-07-17T08:30:00+03:00"), null, crid);
        assertIdempotentUnderRace(
                () -> symptomsService.log(userId, request).id(), "symptom_logs", userId, crid);
    }

    @Test
    void activityLogIsIdempotentUnderRace() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        ActivityLogRequest request = new ActivityLogRequest(
                Map.of("type", "WALKING", "durationMinutes", 30, "intensity", "MODERATE"),
                OffsetDateTime.parse("2026-07-17T08:30:00+03:00"), null, crid);
        assertIdempotentUnderRace(
                () -> activityService.log(userId, request).id(), "activity_logs", userId, crid);
    }

    @Test
    void medicationCreateIsIdempotentUnderRace() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        MedicationRequest request = new MedicationRequest(
                "Atorvastatin", new BigDecimal("20"), Frequency.ONCE_DAILY, List.of("08:00"), true, crid);
        assertIdempotentUnderRace(
                () -> medicationService.create(userId, request).id(), "medications", userId, crid);
    }

    @Test
    void doseLogIsIdempotentUnderRace() throws Exception {
        UUID userId = seedUser();
        UUID medId = UUID.fromString(medicationService.create(userId, new MedicationRequest(
                "Aspirin", new BigDecimal("75"), Frequency.ONCE_DAILY, List.of("08:00"), true, UUID.randomUUID())).id());
        UUID crid = UUID.randomUUID();
        DoseLogRequest request = new DoseLogRequest(
                DoseStatus.TAKEN, LocalDate.parse("2026-07-17"), null,
                OffsetDateTime.parse("2026-07-17T08:30:00+03:00"), null, crid);
        assertIdempotentUnderRace(
                () -> doseLogService.log(userId, medId, request).id(), "dose_logs", userId, crid);
    }
}
