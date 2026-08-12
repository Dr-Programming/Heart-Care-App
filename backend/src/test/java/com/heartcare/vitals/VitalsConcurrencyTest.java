package com.heartcare.vitals;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.dto.VitalLogResponse;
import com.heartcare.vitals.model.VitalType;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
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

class VitalsConcurrencyTest extends AbstractIntegrationTest {

    @Autowired
    VitalsService vitalsService;

    @Autowired
    JdbcTemplate jdbcTemplate;

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, phone, pin_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, TestUsers.nextPhone(), "x", "Test User");
        return id;
    }

    /**
     * Two concurrent submissions of the SAME client_record_id — the retry-on-flaky-connectivity
     * case the sync engine makes routine. Both must get the same record back, idempotently.
     * Before the IdempotentWriter fix, the loser of the race hits UNIQUE (user_id, client_record_id)
     * and throws DataIntegrityViolationException, which the API surfaces as a 500.
     */
    @Test
    void concurrentSameClientRecordIdIsIdempotent() throws Exception {
        UUID userId = seedUser();
        UUID clientRecordId = UUID.randomUUID();
        VitalLogRequest request = new VitalLogRequest(
                VitalType.BLOOD_PRESSURE,
                Map.of("systolic", new BigDecimal("128"), "diastolic", new BigDecimal("82")),
                OffsetDateTime.parse("2026-07-17T08:30:00+03:00"),
                null,
                clientRecordId);

        CountDownLatch startGate = new CountDownLatch(1);
        Callable<VitalLogResponse> submit = () -> {
            startGate.await();
            return vitalsService.log(userId, request);
        };

        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<VitalLogResponse> first = pool.submit(submit);
            Future<VitalLogResponse> second = pool.submit(submit);
            startGate.countDown();   // release both at once

            // Neither call may throw: both must resolve to the same stored row.
            VitalLogResponse a = first.get();
            VitalLogResponse b = second.get();
            assertThat(a.id()).isEqualTo(b.id());
        } finally {
            pool.shutdownNow();
        }

        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT id FROM vitals_logs WHERE user_id = ? AND client_record_id = ?",
                userId, clientRecordId);
        assertThat(rows).hasSize(1);
    }
}
