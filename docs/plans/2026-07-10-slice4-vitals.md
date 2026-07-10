# Slice 4 — Health Vitals Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `vitals` feature to the Spring Boot backend so a patient can log five vital-sign types (blood pressure, glucose, heart rate, weight, cholesterol), receive a server-computed clinical-threshold flag and BMI, and read back their full history with type/date filters.

**Architecture:** Package-by-feature (`com.heartcare.vitals`), mirroring the Slice 3 `medication` feature. One `vitals_logs` row = one metric reading, discriminated by a `type` enum with numeric values in a JSONB map. The server is authoritative for the `flagged` boolean (computed from a centralized threshold table) and for BMI (computed at write-time from the patient profile's height). Append-only (no update/delete), idempotent on `client_record_id`.

**Tech Stack:** Java 21 · Spring Boot 4.1.0 · Spring Data JPA · Hibernate JSONB mapping (`@JdbcTypeCode(SqlTypes.JSON)`) · Flyway · Bean Validation · JUnit 5 · Mockito · AssertJ · Testcontainers (Postgres 16).

## Global Constraints

- **Design source of truth:** `docs/design/2026-07-10-vitals-design.md`. Every decision below traces to it.
- **Base path & envelope:** all endpoints under `/api/v1`; every response wrapped in `com.heartcare.common.response.ApiResponse<T>` (`ApiResponse.ok(data)` / `ApiResponse.ok(data, message)`).
- **Auth:** endpoints require a Bearer JWT; the caller is `@AuthenticationPrincipal com.heartcare.common.security.UserPrincipal` (`principal.userId()` → `UUID`). All queries are scoped to that `userId`. Unauthenticated → 401 (already enforced by the Slice 1 security config).
- **Error mapping** (existing `com.heartcare.common.exception.GlobalExceptionHandler`): `ResourceNotFoundException`→404, bean-validation & malformed/invalid-enum body→400. This slice ADDS `BadRequestException`→400 for service-level `values` validation.
- **Idempotency:** `client_record_id` is nullable; `UNIQUE (user_id, client_record_id)`. A repeat `POST` with an existing `client_record_id` for the user returns the existing row (no new insert).
- **JSONB column name:** `values` is a PostgreSQL reserved word — the column is **`vital_values`**; the JSON API key stays `values` (mapped in DTOs/entity).
- **Type enum values:** `BLOOD_PRESSURE`, `GLUCOSE`, `HEART_RATE`, `WEIGHT`, `CHOLESTEROL`.
- **Commit style:** `feat(backend): …`, `test(backend): …`, `docs(backend): …`. **Do not add any AI co-author trailer.**
- **Test DB:** integration/repository tests extend `com.heartcare.AbstractIntegrationTest` (Testcontainers Postgres); Docker must be running. Run single test class with `mvn -f backend/pom.xml test -Dtest=ClassName`; full suite `mvn -f backend/pom.xml test`.

---

## File Structure

**Production (create under `backend/src/main/java/com/heartcare/`):**
- `vitals/model/VitalType.java` — enum of the 5 types.
- `vitals/model/VitalLog.java` — `@Entity` for `vitals_logs`; JSONB `values` as `Map<String,BigDecimal>`; append-only (`@PrePersist` sets `createdAt`).
- `vitals/VitalsRepository.java` — `JpaRepository`; `findByUserIdAndClientRecordId`, `findHistory`.
- `vitals/VitalThresholds.java` — `@Component`; centralized per-key flag ranges + `isFlagged(values)`.
- `vitals/dto/VitalLogRequest.java` — request record (`type`, `values`, `measuredAt?`, `note?`, `clientRecordId?`).
- `vitals/dto/VitalLogResponse.java` — response record.
- `vitals/VitalsService.java` — validation, BMI, flagging, idempotency, history.
- `vitals/VitalsController.java` — `POST /vitals`, `GET /vitals`.
- `common/exception/BadRequestException.java` — new 400 exception.

**Modified:**
- `common/exception/GlobalExceptionHandler.java` — add `BadRequestException`→400 handler.
- `backend/src/main/resources/db/migration/V5__create_vitals_logs.sql` — new migration.
- `backend/README.md`, `backend/docs/API.md`, `backend/docs/DATABASE.md` — docs.

**Tests (create under `backend/src/test/java/com/heartcare/`):**
- `vitals/VitalsRepositoryTest.java` — JSONB round-trip on real Postgres.
- `vitals/VitalThresholdsTest.java` — pure-unit flag-boundary tests.
- `vitals/VitalsServiceTest.java` — Mockito unit tests.
- `vitals/VitalsControllerIntegrationTest.java` — full endpoint tests.

---

## Task 1: Migration, `VitalType`, `VitalLog` entity, repository (+ round-trip test)

**Files:**
- Create: `backend/src/main/resources/db/migration/V5__create_vitals_logs.sql`
- Create: `backend/src/main/java/com/heartcare/vitals/model/VitalType.java`
- Create: `backend/src/main/java/com/heartcare/vitals/model/VitalLog.java`
- Create: `backend/src/main/java/com/heartcare/vitals/VitalsRepository.java`
- Test: `backend/src/test/java/com/heartcare/vitals/VitalsRepositoryTest.java`

**Interfaces:**
- Consumes: `com.heartcare.AbstractIntegrationTest` (Testcontainers base); `users` table (FK target) seeded via `JdbcTemplate`.
- Produces:
  - `VitalType { BLOOD_PRESSURE, GLUCOSE, HEART_RATE, WEIGHT, CHOLESTEROL }`
  - `VitalLog` entity with getters/setters: `UUID getId()`, `UUID getUserId()/setUserId`, `VitalType getType()/setType`, `Map<String,BigDecimal> getValues()/setValues`, `boolean isFlagged()/setFlagged`, `OffsetDateTime getMeasuredAt()/setMeasuredAt`, `String getNote()/setNote`, `UUID getClientRecordId()/setClientRecordId`, `OffsetDateTime getCreatedAt()`.
  - `VitalsRepository extends JpaRepository<VitalLog, UUID>` with `Optional<VitalLog> findByUserIdAndClientRecordId(UUID, UUID)` and `List<VitalLog> findHistory(UUID userId, LocalDate from, LocalDate to, VitalType type)`.

- [ ] **Step 1: Write the migration**

Create `backend/src/main/resources/db/migration/V5__create_vitals_logs.sql`:

```sql
-- Column is `vital_values` because `values` is a reserved word in PostgreSQL.
CREATE TABLE vitals_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type              VARCHAR(20) NOT NULL,
    vital_values      JSONB NOT NULL,
    flagged           BOOLEAN NOT NULL DEFAULT FALSE,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_vitals_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_vitals_user_measured ON vitals_logs(user_id, measured_at);
CREATE INDEX idx_vitals_user_type     ON vitals_logs(user_id, type);
```

- [ ] **Step 2: Write the `VitalType` enum**

Create `backend/src/main/java/com/heartcare/vitals/model/VitalType.java`:

```java
package com.heartcare.vitals.model;

public enum VitalType {
    BLOOD_PRESSURE,
    GLUCOSE,
    HEART_RATE,
    WEIGHT,
    CHOLESTEROL
}
```

- [ ] **Step 3: Write the `VitalLog` entity**

Create `backend/src/main/java/com/heartcare/vitals/model/VitalLog.java`:

```java
package com.heartcare.vitals.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "vitals_logs")
public class VitalLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private VitalType type;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "vital_values", nullable = false)
    private Map<String, BigDecimal> values = new HashMap<>();

    @Column(nullable = false)
    private boolean flagged;

    @Column(name = "measured_at", nullable = false)
    private OffsetDateTime measuredAt;

    @Column(name = "note")
    private String note;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public VitalLog() {
        // for JPA and service construction
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

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public VitalType getType() {
        return type;
    }

    public void setType(VitalType type) {
        this.type = type;
    }

    public Map<String, BigDecimal> getValues() {
        return values;
    }

    public void setValues(Map<String, BigDecimal> values) {
        this.values = (values == null) ? new HashMap<>() : values;
    }

    public boolean isFlagged() {
        return flagged;
    }

    public void setFlagged(boolean flagged) {
        this.flagged = flagged;
    }

    public OffsetDateTime getMeasuredAt() {
        return measuredAt;
    }

    public void setMeasuredAt(OffsetDateTime measuredAt) {
        this.measuredAt = measuredAt;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public UUID getClientRecordId() {
        return clientRecordId;
    }

    public void setClientRecordId(UUID clientRecordId) {
        this.clientRecordId = clientRecordId;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
```

- [ ] **Step 4: Write the repository**

Create `backend/src/main/java/com/heartcare/vitals/VitalsRepository.java`:

```java
package com.heartcare.vitals;

import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface VitalsRepository extends JpaRepository<VitalLog, UUID> {

    Optional<VitalLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT v FROM VitalLog v
            WHERE v.userId = :userId
              AND (CAST(:from AS LocalDate) IS NULL OR CAST(v.measuredAt AS LocalDate) >= :from)
              AND (CAST(:to AS LocalDate) IS NULL OR CAST(v.measuredAt AS LocalDate) <= :to)
              AND (:type IS NULL OR v.type = :type)
            ORDER BY v.measuredAt DESC
            """)
    List<VitalLog> findHistory(@Param("userId") UUID userId,
                               @Param("from") LocalDate from,
                               @Param("to") LocalDate to,
                               @Param("type") VitalType type);
}
```

- [ ] **Step 5: Write the failing round-trip test**

Create `backend/src/test/java/com/heartcare/vitals/VitalsRepositoryTest.java`:

```java
package com.heartcare.vitals;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class VitalsRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    VitalsRepository vitalsRepository;

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
    void savesAndReloadsVitalWithJsonbValues() {
        UUID userId = seedUser();
        VitalLog vital = new VitalLog();
        vital.setUserId(userId);
        vital.setType(VitalType.BLOOD_PRESSURE);
        vital.setValues(Map.of("systolic", new BigDecimal("120"), "diastolic", new BigDecimal("80")));
        vital.setFlagged(false);
        vital.setMeasuredAt(OffsetDateTime.now());

        VitalLog saved = vitalsRepository.saveAndFlush(vital);

        VitalLog reloaded = vitalsRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getType()).isEqualTo(VitalType.BLOOD_PRESSURE);
        assertThat(reloaded.getValues().get("systolic")).isEqualByComparingTo("120");
        assertThat(reloaded.getValues().get("diastolic")).isEqualByComparingTo("80");
        assertThat(reloaded.isFlagged()).isFalse();
    }

    @Test
    void findByUserIdAndClientRecordIdReturnsMatch() {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        VitalLog vital = new VitalLog();
        vital.setUserId(userId);
        vital.setType(VitalType.WEIGHT);
        vital.setValues(Map.of("weight", new BigDecimal("72.0")));
        vital.setMeasuredAt(OffsetDateTime.now());
        vital.setClientRecordId(crid);
        vitalsRepository.saveAndFlush(vital);

        assertThat(vitalsRepository.findByUserIdAndClientRecordId(userId, crid)).isPresent();
        assertThat(vitalsRepository.findByUserIdAndClientRecordId(userId, UUID.randomUUID())).isEmpty();
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `mvn -f backend/pom.xml test -Dtest=VitalsRepositoryTest`
Expected: PASS (Flyway applies `V5`; JSONB `vital_values` round-trips on real Postgres). If it fails with a Hibernate CAST error on `findHistory`, that method is not exercised here — see "Notes on likely failure points."

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/resources/db/migration/V5__create_vitals_logs.sql \
        backend/src/main/java/com/heartcare/vitals/model/VitalType.java \
        backend/src/main/java/com/heartcare/vitals/model/VitalLog.java \
        backend/src/main/java/com/heartcare/vitals/VitalsRepository.java \
        backend/src/test/java/com/heartcare/vitals/VitalsRepositoryTest.java
git commit -m "feat(backend): add vitals_logs table, entity, repository (Slice 4)"
```

---

## Task 2: `VitalThresholds` — centralized flag logic (+ unit test)

**Files:**
- Create: `backend/src/main/java/com/heartcare/vitals/VitalThresholds.java`
- Test: `backend/src/test/java/com/heartcare/vitals/VitalThresholdsTest.java`

**Interfaces:**
- Consumes: nothing (pure component).
- Produces: `@Component VitalThresholds` with `boolean isFlagged(Map<String,BigDecimal> values)` — returns true if any key in `values` breaches its clinical range. Keys are globally unique across types, so `type` is not needed. `WEIGHT` flags only via the injected `bmi` key; a `weight`-only map is never flagged.

**Flag ranges (breach = value ≤ low OR value ≥ high; `null` bound = that side never breaches):**
`systolic` [90,180] · `diastolic` [60,120] · `glucose` [4.0,11.1] · `heartRate` [40,120] · `bmi` [18.5,30] · `ldl` [null,4.9] · `total` [null,7.5] · `hdl` [1.0,null]. (Uniform `≤`/`≥` semantics — the ≤/< boundary nuance in the design table is clinically immaterial and keeps the table data-driven and adjustable.)

- [ ] **Step 1: Write the failing test**

Create `backend/src/test/java/com/heartcare/vitals/VitalThresholdsTest.java`:

```java
package com.heartcare.vitals;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class VitalThresholdsTest {

    private final VitalThresholds thresholds = new VitalThresholds();

    private static Map<String, BigDecimal> values(Object... kv) {
        Map<String, BigDecimal> m = new java.util.HashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            m.put((String) kv[i], new BigDecimal(kv[i + 1].toString()));
        }
        return m;
    }

    @Test
    void normalBloodPressureNotFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 120, "diastolic", 80))).isFalse();
    }

    @Test
    void highSystolicFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 180, "diastolic", 80))).isTrue();
    }

    @Test
    void lowSystolicFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 90, "diastolic", 70))).isTrue();
    }

    @Test
    void highDiastolicFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 130, "diastolic", 120))).isTrue();
    }

    @Test
    void glucoseBoundaries() {
        assertThat(thresholds.isFlagged(values("glucose", "5.5"))).isFalse();
        assertThat(thresholds.isFlagged(values("glucose", "4.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("glucose", "11.1"))).isTrue();
    }

    @Test
    void heartRateBoundaries() {
        assertThat(thresholds.isFlagged(values("heartRate", 70))).isFalse();
        assertThat(thresholds.isFlagged(values("heartRate", 40))).isTrue();
        assertThat(thresholds.isFlagged(values("heartRate", 120))).isTrue();
    }

    @Test
    void weightWithoutBmiNeverFlagged() {
        assertThat(thresholds.isFlagged(values("weight", 200))).isFalse();
    }

    @Test
    void bmiBoundaries() {
        assertThat(thresholds.isFlagged(values("weight", 70, "bmi", "24.0"))).isFalse();
        assertThat(thresholds.isFlagged(values("weight", 120, "bmi", "30.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("weight", 45, "bmi", "17.0"))).isTrue();
    }

    @Test
    void cholesterolFlags() {
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "1.5", "total", "5.0"))).isFalse();
        assertThat(thresholds.isFlagged(values("ldl", "4.9", "hdl", "1.5", "total", "5.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "0.9", "total", "5.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "1.5", "total", "7.5"))).isTrue();
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mvn -f backend/pom.xml test -Dtest=VitalThresholdsTest`
Expected: FAIL — `VitalThresholds` does not exist (compilation error).

- [ ] **Step 3: Write `VitalThresholds`**

Create `backend/src/main/java/com/heartcare/vitals/VitalThresholds.java`:

```java
package com.heartcare.vitals;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Centralized clinical alert thresholds (FR-VIT-008). Adjust the {@link #RANGES}
 * map to tune bounds; this class is the single seam for later promotion to
 * {@code @ConfigurationProperties} without touching flag logic.
 */
@Component
public class VitalThresholds {

    /** Breach when value &le; low (if non-null) or value &ge; high (if non-null). */
    public record FlagRange(BigDecimal low, BigDecimal high) {
        public boolean breached(BigDecimal v) {
            return (low != null && v.compareTo(low) <= 0)
                    || (high != null && v.compareTo(high) >= 0);
        }
    }

    private static final Map<String, FlagRange> RANGES = Map.of(
            "systolic", new FlagRange(bd("90"), bd("180")),
            "diastolic", new FlagRange(bd("60"), bd("120")),
            "glucose", new FlagRange(bd("4.0"), bd("11.1")),
            "heartRate", new FlagRange(bd("40"), bd("120")),
            "bmi", new FlagRange(bd("18.5"), bd("30")),
            "ldl", new FlagRange(null, bd("4.9")),
            "total", new FlagRange(null, bd("7.5")),
            "hdl", new FlagRange(bd("1.0"), null));

    public boolean isFlagged(Map<String, BigDecimal> values) {
        return values.entrySet().stream().anyMatch(e -> {
            FlagRange range = RANGES.get(e.getKey());
            return range != null && e.getValue() != null && range.breached(e.getValue());
        });
    }

    private static BigDecimal bd(String s) {
        return new BigDecimal(s);
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mvn -f backend/pom.xml test -Dtest=VitalThresholdsTest`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/heartcare/vitals/VitalThresholds.java \
        backend/src/test/java/com/heartcare/vitals/VitalThresholdsTest.java
git commit -m "feat(backend): add VitalThresholds flag logic with unit tests (Slice 4)"
```

---

## Task 3: DTOs, `BadRequestException`, and `VitalsService` (+ unit tests)

**Files:**
- Create: `backend/src/main/java/com/heartcare/common/exception/BadRequestException.java`
- Modify: `backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java`
- Create: `backend/src/main/java/com/heartcare/vitals/dto/VitalLogRequest.java`
- Create: `backend/src/main/java/com/heartcare/vitals/dto/VitalLogResponse.java`
- Create: `backend/src/main/java/com/heartcare/vitals/VitalsService.java`
- Test: `backend/src/test/java/com/heartcare/vitals/VitalsServiceTest.java`

**Interfaces:**
- Consumes: `VitalsRepository` (Task 1); `VitalThresholds` (Task 2); `com.heartcare.patient.PatientProfileRepository` (existing Slice 2 — `findById(UUID)` → `Optional<PatientProfile>`, `PatientProfile.getHeightCm()` → nullable `Integer`); `com.heartcare.common.exception.BadRequestException` (new).
- Produces:
  - `VitalLogRequest(VitalType type, Map<String,BigDecimal> values, OffsetDateTime measuredAt, String note, UUID clientRecordId)`.
  - `VitalLogResponse(String id, VitalType type, Map<String,BigDecimal> values, boolean flagged, OffsetDateTime measuredAt, String note, String clientRecordId, OffsetDateTime createdAt)`.
  - `VitalsService` with `VitalLogResponse log(UUID userId, VitalLogRequest request)` and `List<VitalLogResponse> history(UUID userId, VitalType type, LocalDate from, LocalDate to)`.

> **Cross-feature note:** reading `height_cm` from `PatientProfileRepository` is the one intentional cross-feature read (design §8) — a narrow, read-only dependency on the patient feature's repository. Keep it to `findById(userId).map(PatientProfile::getHeightCm)`; do not touch patient DTOs/service internals.

- [ ] **Step 1: Write `BadRequestException`**

Create `backend/src/main/java/com/heartcare/common/exception/BadRequestException.java`:

```java
package com.heartcare.common.exception;

import java.io.Serial;

public class BadRequestException extends RuntimeException {
    @Serial
    private static final long serialVersionUID = 1L;

    public BadRequestException(String message) {
        super(message);
    }
}
```

- [ ] **Step 2: Add the 400 handler**

In `backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java`, add this handler method (place it after `handleNotFound`, alongside the other `@ExceptionHandler` methods):

```java
    @ExceptionHandler(BadRequestException.class)
    public ResponseEntity<ApiResponse<Void>> handleBadRequest(BadRequestException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(ex.getMessage()));
    }
```

(No new imports needed — `HttpStatus`, `ResponseEntity`, `ApiResponse`, `ExceptionHandler` are already imported.)

- [ ] **Step 3: Write the DTOs**

Create `backend/src/main/java/com/heartcare/vitals/dto/VitalLogRequest.java`:

```java
package com.heartcare.vitals.dto;

import com.heartcare.vitals.model.VitalType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

public record VitalLogRequest(
        @NotNull(message = "type is required")
        VitalType type,

        @NotNull(message = "values is required")
        Map<String, BigDecimal> values,

        OffsetDateTime measuredAt,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        UUID clientRecordId) {
}
```

Create `backend/src/main/java/com/heartcare/vitals/dto/VitalLogResponse.java`:

```java
package com.heartcare.vitals.dto;

import com.heartcare.vitals.model.VitalType;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Map;

public record VitalLogResponse(
        String id,
        VitalType type,
        Map<String, BigDecimal> values,
        boolean flagged,
        OffsetDateTime measuredAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
```

- [ ] **Step 4: Write the failing service test**

Create `backend/src/test/java/com/heartcare/vitals/VitalsServiceTest.java`:

```java
package com.heartcare.vitals;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.patient.PatientProfileRepository;
import com.heartcare.patient.model.PatientProfile;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.dto.VitalLogResponse;
import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VitalsServiceTest {

    @Mock
    VitalsRepository vitalsRepository;

    @Mock
    PatientProfileRepository profileRepository;

    VitalsService service;

    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new VitalsService(vitalsRepository, profileRepository, new VitalThresholds());
    }

    private VitalLogRequest request(VitalType type, Map<String, BigDecimal> values, UUID crid) {
        return new VitalLogRequest(type, values, null, null, crid);
    }

    private static Map<String, BigDecimal> values(Object... kv) {
        Map<String, BigDecimal> m = new HashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            m.put((String) kv[i], new BigDecimal(kv[i + 1].toString()));
        }
        return m;
    }

    @Test
    void logComputesFlaggedTrueForHighBp() {
        when(vitalsRepository.save(any(VitalLog.class))).thenAnswer(inv -> inv.getArgument(0));

        VitalLogResponse response = service.log(userId,
                request(VitalType.BLOOD_PRESSURE, values("systolic", 190, "diastolic", 100), null));

        assertThat(response.flagged()).isTrue();
    }

    @Test
    void logComputesFlaggedFalseForNormalGlucose() {
        when(vitalsRepository.save(any(VitalLog.class))).thenAnswer(inv -> inv.getArgument(0));

        VitalLogResponse response = service.log(userId,
                request(VitalType.GLUCOSE, values("glucose", "5.5"), null));

        assertThat(response.flagged()).isFalse();
    }

    @Test
    void logInjectsBmiFromProfileHeight() {
        PatientProfile profile = new PatientProfile(userId);
        profile.setHeightCm(170);
        when(profileRepository.findById(userId)).thenReturn(Optional.of(profile));
        when(vitalsRepository.save(any(VitalLog.class))).thenAnswer(inv -> inv.getArgument(0));

        VitalLogResponse response = service.log(userId,
                request(VitalType.WEIGHT, values("weight", 72), null));

        // 72 / (1.70^2) = 24.913... -> 24.9
        assertThat(response.values().get("bmi")).isEqualByComparingTo("24.9");
    }

    @Test
    void logOmitsBmiWhenNoHeight() {
        when(profileRepository.findById(userId)).thenReturn(Optional.empty());
        when(vitalsRepository.save(any(VitalLog.class))).thenAnswer(inv -> inv.getArgument(0));

        VitalLogResponse response = service.log(userId,
                request(VitalType.WEIGHT, values("weight", 72), null));

        assertThat(response.values()).doesNotContainKey("bmi");
        assertThat(response.flagged()).isFalse();
    }

    @Test
    void logDefaultsMeasuredAtWhenNull() {
        when(vitalsRepository.save(any(VitalLog.class))).thenAnswer(inv -> inv.getArgument(0));

        VitalLogResponse response = service.log(userId,
                request(VitalType.HEART_RATE, values("heartRate", 70), null));

        assertThat(response.measuredAt()).isNotNull();
    }

    @Test
    void logIsIdempotentOnClientRecordId() {
        UUID crid = UUID.randomUUID();
        VitalLog existing = new VitalLog();
        existing.setUserId(userId);
        existing.setType(VitalType.GLUCOSE);
        existing.setValues(values("glucose", "5.0"));
        existing.setMeasuredAt(OffsetDateTime.now());
        when(vitalsRepository.findByUserIdAndClientRecordId(userId, crid)).thenReturn(Optional.of(existing));

        VitalLogResponse response = service.log(userId,
                request(VitalType.GLUCOSE, values("glucose", "9.9"), crid));

        assertThat(response.values().get("glucose")).isEqualByComparingTo("5.0");
        verify(vitalsRepository, never()).save(any());
    }

    @Test
    void logIgnoresClientSentBmi() {
        PatientProfile profile = new PatientProfile(userId);
        profile.setHeightCm(170);
        when(profileRepository.findById(userId)).thenReturn(Optional.of(profile));
        when(vitalsRepository.save(any(VitalLog.class))).thenAnswer(inv -> inv.getArgument(0));

        VitalLogResponse response = service.log(userId,
                request(VitalType.WEIGHT, values("weight", 72, "bmi", "999"), null));

        // client-sent bmi stripped, server recomputes
        assertThat(response.values().get("bmi")).isEqualByComparingTo("24.9");
    }

    @Test
    void logRejectsMissingKey() {
        assertThatThrownBy(() -> service.log(userId,
                request(VitalType.BLOOD_PRESSURE, values("systolic", 120), null)))
                .isInstanceOf(BadRequestException.class);
        verify(vitalsRepository, never()).save(any());
    }

    @Test
    void logRejectsSystolicNotGreaterThanDiastolic() {
        assertThatThrownBy(() -> service.log(userId,
                request(VitalType.BLOOD_PRESSURE, values("systolic", 80, "diastolic", 80), null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsOutOfRange() {
        assertThatThrownBy(() -> service.log(userId,
                request(VitalType.HEART_RATE, values("heartRate", 900), null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void historyDelegatesToRepositoryWithFilters() {
        LocalDate from = LocalDate.of(2026, 7, 1);
        LocalDate to = LocalDate.of(2026, 7, 31);
        when(vitalsRepository.findHistory(userId, from, to, VitalType.GLUCOSE)).thenReturn(List.of());

        service.history(userId, VitalType.GLUCOSE, from, to);

        verify(vitalsRepository).findHistory(userId, from, to, VitalType.GLUCOSE);
    }
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `mvn -f backend/pom.xml test -Dtest=VitalsServiceTest`
Expected: FAIL — `VitalsService` does not exist (compilation error).

- [ ] **Step 6: Write `VitalsService`**

Create `backend/src/main/java/com/heartcare/vitals/VitalsService.java`:

```java
package com.heartcare.vitals;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.patient.PatientProfileRepository;
import com.heartcare.patient.model.PatientProfile;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.dto.VitalLogResponse;
import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class VitalsService {

    private static final Map<VitalType, Set<String>> REQUIRED_KEYS = Map.of(
            VitalType.BLOOD_PRESSURE, Set.of("systolic", "diastolic"),
            VitalType.GLUCOSE, Set.of("glucose"),
            VitalType.HEART_RATE, Set.of("heartRate"),
            VitalType.WEIGHT, Set.of("weight"),
            VitalType.CHOLESTEROL, Set.of("ldl", "hdl", "total"));

    // Input-sanity ranges (reject typos/garbage); distinct from clinical flag thresholds.
    private static final Map<String, BigDecimal[]> SANE_RANGE = Map.of(
            "systolic", range(40, 300),
            "diastolic", range(40, 300),
            "glucose", range(0, 50),
            "heartRate", range(20, 300),
            "weight", range(0, 500),
            "ldl", range(0, 30),
            "hdl", range(0, 30),
            "total", range(0, 30));

    private final VitalsRepository vitalsRepository;
    private final PatientProfileRepository profileRepository;
    private final VitalThresholds thresholds;

    public VitalsService(VitalsRepository vitalsRepository,
                         PatientProfileRepository profileRepository,
                         VitalThresholds thresholds) {
        this.vitalsRepository = vitalsRepository;
        this.profileRepository = profileRepository;
        this.thresholds = thresholds;
    }

    @Transactional
    public VitalLogResponse log(UUID userId, VitalLogRequest request) {
        if (request.clientRecordId() != null) {
            var existing = vitalsRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        Map<String, BigDecimal> values = validateAndClean(request.type(), request.values());

        if (request.type() == VitalType.WEIGHT) {
            Integer heightCm = profileRepository.findById(userId)
                    .map(PatientProfile::getHeightCm)
                    .orElse(null);
            if (heightCm != null) {
                values.put("bmi", computeBmi(values.get("weight"), heightCm));
            }
        }

        VitalLog vital = new VitalLog();
        vital.setUserId(userId);
        vital.setType(request.type());
        vital.setValues(values);
        vital.setFlagged(thresholds.isFlagged(values));
        vital.setMeasuredAt(request.measuredAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.measuredAt());
        vital.setNote(request.note());
        vital.setClientRecordId(request.clientRecordId());
        return toResponse(vitalsRepository.save(vital));
    }

    @Transactional(readOnly = true)
    public List<VitalLogResponse> history(UUID userId, VitalType type, LocalDate from, LocalDate to) {
        return vitalsRepository.findHistory(userId, from, to, type)
                .stream().map(this::toResponse).toList();
    }

    private Map<String, BigDecimal> validateAndClean(VitalType type, Map<String, BigDecimal> raw) {
        if (raw == null) {
            throw new BadRequestException("values is required");
        }
        Map<String, BigDecimal> values = new HashMap<>(raw);
        values.remove("bmi"); // server-owned; ignored if the client sends it

        Set<String> required = REQUIRED_KEYS.get(type);
        if (!values.keySet().equals(required)) {
            throw new BadRequestException("values for " + type + " must contain exactly " + required);
        }
        for (Map.Entry<String, BigDecimal> entry : values.entrySet()) {
            BigDecimal value = entry.getValue();
            if (value == null) {
                throw new BadRequestException(entry.getKey() + " must be a number");
            }
            BigDecimal[] sane = SANE_RANGE.get(entry.getKey());
            if (value.compareTo(sane[0]) < 0 || value.compareTo(sane[1]) > 0) {
                throw new BadRequestException(entry.getKey() + " is out of range");
            }
        }
        if (type == VitalType.BLOOD_PRESSURE
                && values.get("systolic").compareTo(values.get("diastolic")) <= 0) {
            throw new BadRequestException("systolic must be greater than diastolic");
        }
        return values;
    }

    private BigDecimal computeBmi(BigDecimal weightKg, int heightCm) {
        BigDecimal heightM = BigDecimal.valueOf(heightCm).movePointLeft(2); // cm -> m
        return weightKg.divide(heightM.multiply(heightM), 1, RoundingMode.HALF_UP);
    }

    private VitalLogResponse toResponse(VitalLog v) {
        return new VitalLogResponse(
                v.getId() == null ? null : v.getId().toString(),
                v.getType(),
                v.getValues(),
                v.isFlagged(),
                v.getMeasuredAt(),
                v.getNote(),
                v.getClientRecordId() == null ? null : v.getClientRecordId().toString(),
                v.getCreatedAt());
    }

    private static BigDecimal[] range(int low, int high) {
        return new BigDecimal[]{BigDecimal.valueOf(low), BigDecimal.valueOf(high)};
    }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `mvn -f backend/pom.xml test -Dtest=VitalsServiceTest`
Expected: PASS (all 11 tests). Note: if Mockito reports unnecessary-stubbing for a test that doesn't reach `save`/`findById`, add `import static org.mockito.Mockito.lenient;` and wrap the affected `when(...)` in `lenient(...)`.

- [ ] **Step 8: Commit**

```bash
git add backend/src/main/java/com/heartcare/common/exception/BadRequestException.java \
        backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java \
        backend/src/main/java/com/heartcare/vitals/dto/VitalLogRequest.java \
        backend/src/main/java/com/heartcare/vitals/dto/VitalLogResponse.java \
        backend/src/main/java/com/heartcare/vitals/VitalsService.java \
        backend/src/test/java/com/heartcare/vitals/VitalsServiceTest.java
git commit -m "feat(backend): add VitalsService with flag/BMI/validation and unit tests (Slice 4)"
```

---

## Task 4: `VitalsController` + integration tests

**Files:**
- Create: `backend/src/main/java/com/heartcare/vitals/VitalsController.java`
- Test: `backend/src/test/java/com/heartcare/vitals/VitalsControllerIntegrationTest.java`

**Interfaces:**
- Consumes: `VitalsService.log`, `VitalsService.history` (Task 3); `UserPrincipal`, `ApiResponse` (shared); real `POST /api/v1/auth/register` (returns `$.data.token`) and `PUT /api/v1/patients/me` (accepts `{ "heightCm": <int> }`) for test setup.
- Produces: `POST /api/v1/vitals`, `GET /api/v1/vitals?type=&from=&to=`.

- [ ] **Step 1: Write the controller**

Create `backend/src/main/java/com/heartcare/vitals/VitalsController.java`:

```java
package com.heartcare.vitals;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.dto.VitalLogResponse;
import com.heartcare.vitals.model.VitalType;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class VitalsController {

    private final VitalsService vitalsService;

    public VitalsController(VitalsService vitalsService) {
        this.vitalsService = vitalsService;
    }

    @PostMapping("/vitals")
    public ApiResponse<VitalLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody VitalLogRequest request) {
        return ApiResponse.ok(vitalsService.log(principal.userId(), request), "Vital logged");
    }

    @GetMapping("/vitals")
    public ApiResponse<List<VitalLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) VitalType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(vitalsService.history(principal.userId(), type, from, to));
    }
}
```

- [ ] **Step 2: Write the failing integration test**

Create `backend/src/test/java/com/heartcare/vitals/VitalsControllerIntegrationTest.java`:

```java
package com.heartcare.vitals;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.heartcare.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.UUID;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class VitalsControllerIntegrationTest extends AbstractIntegrationTest {

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

    private String registerAndGetToken() throws Exception {
        ObjectNode body = objectMapper.createObjectNode();
        body.put("fullName", "Abebe");
        body.put("email", UUID.randomUUID() + "@example.com");
        body.put("password", "password1");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body.toString()))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    private void setHeight(String token, int heightCm) throws Exception {
        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"heightCm\": " + heightCm + " }"))
                .andExpect(status().isOk());
    }

    private void postVital(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk());
    }

    @Test
    void unauthenticatedReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/vitals")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 } }"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logThenHistoryReturnsVital() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 }, \"note\": \"fasting\" }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.type").value("GLUCOSE"))
                .andExpect(jsonPath("$.data.flagged").value(false))
                .andExpect(jsonPath("$.data.values.glucose").value(5.5));

        mockMvc.perform(get("/api/v1/vitals").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].type").value("GLUCOSE"))
                .andExpect(jsonPath("$.data[0].note").value("fasting"));
    }

    @Test
    void highBloodPressureIsFlagged() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": 190, \"diastolic\": 100 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.flagged").value(true));
    }

    @Test
    void weightReturnsComputedBmiWhenHeightSet() throws Exception {
        String token = registerAndGetToken();
        setHeight(token, 170);
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"WEIGHT\", \"values\": { \"weight\": 72 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.values.bmi").value(24.9));
    }

    @Test
    void weightHasNoBmiWhenNoHeight() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"WEIGHT\", \"values\": { \"weight\": 72 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.values.bmi").doesNotExist());
    }

    @Test
    void cholesterolCanBeLoggedAndFlagged() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"CHOLESTEROL\", \"values\": { \"ldl\": 5.0, \"hdl\": 1.2, \"total\": 6.0 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.type").value("CHOLESTEROL"))
                .andExpect(jsonPath("$.data.values.ldl").value(5.0))
                .andExpect(jsonPath("$.data.flagged").value(true));
    }

    @Test
    void historyFiltersByType() throws Exception {
        String token = registerAndGetToken();
        postVital(token, "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 } }");
        postVital(token, "{ \"type\": \"HEART_RATE\", \"values\": { \"heartRate\": 70 } }");

        mockMvc.perform(get("/api/v1/vitals?type=HEART_RATE").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].type").value("HEART_RATE"));
    }

    @Test
    void historyFiltersByDateRange() throws Exception {
        String token = registerAndGetToken();
        postVital(token, "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 }, \"measuredAt\": \"2026-07-05T08:00:00Z\" }");
        postVital(token, "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 6.0 }, \"measuredAt\": \"2026-07-20T08:00:00Z\" }");

        mockMvc.perform(get("/api/v1/vitals?from=2026-07-10&to=2026-07-31")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].values.glucose").value(6.0));
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String crid = UUID.randomUUID().toString();
        String body = "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 }, \"clientRecordId\": \"%s\" }".formatted(crid);
        postVital(token, body);
        postVital(token, body);

        mockMvc.perform(get("/api/v1/vitals").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void invalidTypeReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"SUGAR\", \"values\": { \"x\": 1 } }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void missingValuesKeyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": 120 } }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void systolicNotGreaterThanDiastolicReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": 80, \"diastolic\": 80 } }"))
                .andExpect(status().isBadRequest());
    }
}
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `mvn -f backend/pom.xml test -Dtest=VitalsControllerIntegrationTest`
Expected: PASS (all endpoints, including the `findHistory` query, exercised on real Postgres). If `historyFiltersByDateRange` fails on a Hibernate CAST error, see "Notes on likely failure points."

- [ ] **Step 4: Run the full backend suite**

Run: `mvn -f backend/pom.xml test`
Expected: PASS — Slices 1–3 tests plus the new vitals tests all green.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/heartcare/vitals/VitalsController.java \
        backend/src/test/java/com/heartcare/vitals/VitalsControllerIntegrationTest.java
git commit -m "feat(backend): add vitals endpoints with integration tests (Slice 4)"
```

---

## Task 5: Documentation

**Files:**
- Modify: `backend/README.md`
- Modify: `backend/docs/API.md`
- Modify: `backend/docs/DATABASE.md`

**Interfaces:** none (docs only).

- [ ] **Step 1: Update the build-progress table**

In `backend/README.md`, change the Slice 4 row from:

```
| 4 | Vitals | ⬜ Not started |
```
to:
```
| 4 | Vitals (BP/glucose/heart-rate/weight+BMI/cholesterol logging, server-computed flag, JSONB values) | ✅ Done |
```

- [ ] **Step 2: Document the endpoints in `backend/docs/API.md`**

Add a new section after the Medications & Dose Logs section (match the existing heading/format style in that file):

````markdown
### Health Vitals — Bearer JWT

All under `/api/v1`. Each reading is one row of a given `type`; numeric values live in a JSON `values` map. The server computes `flagged` (clinical alert threshold, FR-VIT-008) and, for `WEIGHT`, `bmi` from the profile's `heightCm`. Append-only; idempotent on `clientRecordId`.

Per-type `values` keys (canonical units):
- `BLOOD_PRESSURE` — `systolic`, `diastolic` (mmHg; `systolic > diastolic`)
- `GLUCOSE` — `glucose` (mmol/L)
- `HEART_RATE` — `heartRate` (bpm)
- `WEIGHT` — `weight` (kg); response adds `bmi` when height is known
- `CHOLESTEROL` — `ldl`, `hdl`, `total` (mmol/L)

#### POST `/vitals`
Request:
```json
{ "type": "BLOOD_PRESSURE", "values": { "systolic": 190, "diastolic": 100 },
  "measuredAt": "2026-07-10T08:15:00Z", "note": "felt dizzy", "clientRecordId": "..." }
```
`measuredAt`, `note`, `clientRecordId` optional; any client-sent `flagged`/`bmi` is ignored. Response `data`:
```json
{ "id": "...", "type": "BLOOD_PRESSURE", "values": { "systolic": 190, "diastolic": 100 },
  "flagged": true, "measuredAt": "2026-07-10T08:15:00Z", "note": "felt dizzy",
  "clientRecordId": "...", "createdAt": "2026-07-10T08:15:02Z" }
```
`400` on unknown `type`, missing/unknown `values` key, non-numeric or out-of-range value, or `systolic <= diastolic`.

#### GET `/vitals?type=&from=&to=`
Optional `type` (enum), `from`/`to` (ISO dates, filter on `measuredAt`). Returns the user's readings, newest first.
````

- [ ] **Step 3: Document the table in `backend/docs/DATABASE.md`**

Add a `vitals_logs` table description and a migration-log entry (match the existing format used for `V3`/`V4`):

```markdown
### V4 — `create_dose_logs`
... (existing) ...

### V5 — `create_vitals_logs`

`vitals_logs` — one row per vital-sign reading.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK → users(id) | ON DELETE CASCADE |
| type | VARCHAR(20) | BLOOD_PRESSURE / GLUCOSE / HEART_RATE / WEIGHT / CHOLESTEROL |
| vital_values | JSONB | per-type numeric map (`values` is a reserved word, hence `vital_values`); server injects `bmi` for weight |
| flagged | BOOLEAN | server-computed clinical alert flag (FR-VIT-008) |
| measured_at | TIMESTAMPTZ | when the reading was taken |
| note | TEXT | optional |
| client_record_id | UUID | offline idempotency key; `UNIQUE (user_id, client_record_id)` |
| created_at | TIMESTAMPTZ | |

Indexes: `(user_id, measured_at)`, `(user_id, type)`.
```

- [ ] **Step 4: Commit**

```bash
git add backend/README.md backend/docs/API.md backend/docs/DATABASE.md
git commit -m "docs(backend): document Slice 4 vitals endpoints and schema"
```

---

## Verification (end of slice)

- [ ] `mvn -f backend/pom.xml test` — full suite green (Slices 1–4).
- [ ] Optional manual smoke: `mvn -f backend/pom.xml spring-boot:run`, then register → `PUT /patients/me` height → `POST /vitals` (weight) → confirm `bmi` in response → `POST /vitals` (systolic 190) → confirm `flagged:true` → `GET /vitals?type=WEIGHT`.
- [ ] `backend/README.md` shows Slice 4 ✅; `API.md` and `DATABASE.md` updated.

---

## Notes on likely failure points

1. **`values` reserved word** — the column is `vital_values`, not `values`. The entity maps it via `@Column(name = "vital_values")`. Do not rename to `values` in DDL; it will fail to parse on Postgres.
2. **Hibernate `CAST(v.measuredAt AS LocalDate)`** in `findHistory` — this reuses the Slice 3 `CAST(:param AS LocalDate)` idiom (proven in `DoseLogRepository`) and additionally casts the timestamp column to date. If a Hibernate version rejects casting the column to `LocalDate`, the fallback is to keep `from`/`to` as `LocalDate` at the controller, convert them in the service to UTC bounds (`from.atStartOfDay().atOffset(UTC)` and `to.plusDays(1).atStartOfDay().atOffset(UTC)`), and change the query to `v.measuredAt >= :fromTs AND v.measuredAt < :toTs` with the same `CAST(:fromTs AS ...) IS NULL` null-guards. Only apply the fallback if the primary form fails in Task 4.
3. **JSONB numeric round-trip** — values are stored/loaded as `BigDecimal`; assert with `isEqualByComparingTo` (unit tests) and jsonPath numeric matchers (integration). A JSON integer like `190` deserializes to an int matcher; a decimal like `5.5`/`24.9` to a double matcher — the tests above use the matching literal form.
4. **Mockito unnecessary-stubbing** — `VitalsServiceTest` stubs only what each test uses. If strict-stubbing complains for a test that doesn't reach `save`/`findById`, wrap that stub in `lenient(...)` (already imported).
5. **Profile height for BMI** is read via `PatientProfileRepository.findById(userId)`; a user who never called `PUT /patients/me` has no profile row → `Optional.empty()` → no `bmi` (covered by `weightHasNoBmiWhenNoHeight`).
6. **Client sends `bmi`** — stripped in `validateAndClean` before the required-keys check, so it neither causes a 400 nor overrides the server value (covered by `logIgnoresClientSentBmi`).
```
