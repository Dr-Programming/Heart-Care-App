# Slice 3 — Medications & Dose Logs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add medication CRUD and append-only per-dose logging for the authenticated patient via `/api/v1/medications` and `/api/v1/dose-logs`, persisted in new `medications` and `dose_logs` tables.

**Architecture:** New package-by-feature module `com.heartcare.medication`, following the Slice 1/2 conventions exactly (record DTOs, constructor-injected `@Service`, `ApiResponse<T>` envelope, `@AuthenticationPrincipal UserPrincipal`, JSONB via `@JdbcTypeCode(SqlTypes.JSON)`). Dose logs are an append-only event log written by the device; the server stores and serves data and never computes "what's due now." Both tables carry a `client_record_id` sync-idempotency key so a replayed offline `POST` returns the existing row instead of duplicating. The module never imports `com.heartcare.auth`.

**Tech Stack:** Java 21, Spring Boot 4.1.0 (Spring Framework 7 / Hibernate 7), Spring Data JPA, Bean Validation, Flyway, PostgreSQL 16, JUnit 5 + Mockito + Testcontainers.

## Global Constraints

- Base path `/api/v1`; every endpoint returns the `ApiResponse<T>` envelope (`common/response/ApiResponse`): `ApiResponse.ok(data)`, `ApiResponse.ok(data, message)`, `ApiResponse.error(message)`.
- `spring.jpa.hibernate.ddl-auto=validate` — JPA entities MUST match the Flyway schema exactly. Flyway owns the schema; never edit an applied migration, add a new `V#__description.sql`.
- Features never import from each other directly — the `medication` package must NOT import anything from `com.heartcare.auth`. Shared infra (`common/`) and the JWT `UserPrincipal` (`common/security`) are allowed.
- DTOs are Java `record`s and stay inside the `medication` package.
- No new Maven dependencies — JSONB uses Hibernate's built-in `@JdbcTypeCode(SqlTypes.JSON)`.
- Ownership is enforced on every by-id operation: a medication or dose not owned by the token's user → `404` via `ResourceNotFoundException` (handled by `GlobalExceptionHandler`). Never reveal existence with a 403.
- Commit messages: **no AI co-author trailer** (project rule).
- Build/test from the `backend/` directory: `mvn test` (Docker must be running for Testcontainers).
- Entities use `@Id @GeneratedValue(strategy = GenerationType.UUID)` for generated primary keys (matches `User`).
- `SecurityConfig` already permits only `/auth/register` + `/auth/login` and requires auth for `.anyRequest()`, so all new routes are protected automatically — no security change needed.

---

## File Structure

**Create (main):**
- `backend/src/main/resources/db/migration/V3__create_medications.sql`
- `backend/src/main/resources/db/migration/V4__create_dose_logs.sql`
- `backend/src/main/java/com/heartcare/medication/model/Frequency.java` — enum
- `backend/src/main/java/com/heartcare/medication/model/DoseStatus.java` — enum
- `backend/src/main/java/com/heartcare/medication/model/Medication.java` — `@Entity`
- `backend/src/main/java/com/heartcare/medication/model/DoseLog.java` — `@Entity`
- `backend/src/main/java/com/heartcare/medication/MedicationRepository.java`
- `backend/src/main/java/com/heartcare/medication/DoseLogRepository.java`
- `backend/src/main/java/com/heartcare/medication/dto/MedicationRequest.java`
- `backend/src/main/java/com/heartcare/medication/dto/MedicationResponse.java`
- `backend/src/main/java/com/heartcare/medication/dto/DoseLogRequest.java`
- `backend/src/main/java/com/heartcare/medication/dto/DoseLogResponse.java`
- `backend/src/main/java/com/heartcare/medication/MedicationService.java`
- `backend/src/main/java/com/heartcare/medication/DoseLogService.java`
- `backend/src/main/java/com/heartcare/medication/MedicationController.java`
- `backend/src/main/java/com/heartcare/medication/DoseLogController.java`

**Create (test):**
- `backend/src/test/java/com/heartcare/medication/MedicationRepositoryTest.java`
- `backend/src/test/java/com/heartcare/medication/MedicationServiceTest.java`
- `backend/src/test/java/com/heartcare/medication/MedicationControllerIntegrationTest.java`
- `backend/src/test/java/com/heartcare/medication/DoseLogServiceTest.java`
- `backend/src/test/java/com/heartcare/medication/DoseLogControllerIntegrationTest.java`

**Modify:**
- `backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java` — add `HttpMessageNotReadableException` → 400 handler (Task 4).
- `backend/README.md` — flip Slice 3 to ✅ (Task 8).
- `backend/docs/API.md` — document the six endpoints (Task 8).
- `backend/docs/DATABASE.md` — document `medications` + `dose_logs`, `V3`/`V4` log entries (Task 8).

---

### Task 1: Migrations, enums, entities, repositories (+ round-trip test)

Creates both tables plus the JPA layer, verified by a Testcontainers repository round-trip that exercises the JSONB, enum, `NUMERIC`, and FK mappings. Tasks 1's SQL and entities are one commit group.

**Files:**
- Create: `V3__create_medications.sql`, `V4__create_dose_logs.sql`
- Create: `model/Frequency.java`, `model/DoseStatus.java`, `model/Medication.java`, `model/DoseLog.java`
- Create: `MedicationRepository.java`, `DoseLogRepository.java`
- Test: `MedicationRepositoryTest.java`

**Interfaces:**
- Consumes: `users(id)` from `V1`.
- Produces:
  - tables `medications`, `dose_logs`.
  - `enum Frequency { ONCE_DAILY, BID, TID, CUSTOM }`, `enum DoseStatus { TAKEN, MISSED, SKIPPED }`.
  - `class Medication` — no-arg ctor; getters/setters for `id`(get), `userId`, `name`, `doseMg`(`BigDecimal`), `frequency`, `scheduleTimes`(`List<String>`), `active`(`boolean`), `clientRecordId`(`UUID`), `createdAt`(get), `updatedAt`(get).
  - `class DoseLog` — no-arg ctor; getters/setters for `id`(get), `medicationId`, `userId`, `scheduledDate`(`LocalDate`), `scheduledTime`(`LocalTime`), `status`(`DoseStatus`), `loggedAt`(`OffsetDateTime`), `note`(`String`), `clientRecordId`(`UUID`), `createdAt`(get).
  - `interface MedicationRepository extends JpaRepository<Medication, UUID>` with `findByIdAndUserId`, `findByUserIdAndClientRecordId`, `findByUserIdOrderByCreatedAtDesc`, `findByUserIdAndActiveTrueOrderByCreatedAtDesc`.
  - `interface DoseLogRepository extends JpaRepository<DoseLog, UUID>` with `findByUserIdAndClientRecordId` and `findHistory`.

- [ ] **Step 1: Write `V3__create_medications.sql`**

Create `backend/src/main/resources/db/migration/V3__create_medications.sql`:

```sql
CREATE TABLE medications (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name              VARCHAR(255) NOT NULL,
    dose_mg           NUMERIC(8,2) NOT NULL,
    frequency         VARCHAR(20) NOT NULL,
    schedule_times    JSONB NOT NULL DEFAULT '[]'::jsonb,
    active            BOOLEAN NOT NULL DEFAULT TRUE,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_medications_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_medications_user ON medications(user_id);
```

- [ ] **Step 2: Write `V4__create_dose_logs.sql`**

Create `backend/src/main/resources/db/migration/V4__create_dose_logs.sql`:

```sql
CREATE TABLE dose_logs (
    id                UUID PRIMARY KEY,
    medication_id     UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_date    DATE NOT NULL,
    scheduled_time    TIME,
    status            VARCHAR(10) NOT NULL,
    logged_at         TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_dose_logs_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_dose_logs_user_date ON dose_logs(user_id, scheduled_date);
CREATE INDEX idx_dose_logs_medication ON dose_logs(medication_id);
```

- [ ] **Step 3: Create the enums**

Create `backend/src/main/java/com/heartcare/medication/model/Frequency.java`:

```java
package com.heartcare.medication.model;

public enum Frequency {
    ONCE_DAILY, BID, TID, CUSTOM
}
```

Create `backend/src/main/java/com/heartcare/medication/model/DoseStatus.java`:

```java
package com.heartcare.medication.model;

public enum DoseStatus {
    TAKEN, MISSED, SKIPPED
}
```

- [ ] **Step 4: Create the `Medication` entity**

Create `backend/src/main/java/com/heartcare/medication/model/Medication.java`:

```java
package com.heartcare.medication.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "medications")
public class Medication {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private String name;

    @Column(name = "dose_mg", nullable = false, precision = 8, scale = 2)
    private BigDecimal doseMg;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Frequency frequency;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "schedule_times", nullable = false)
    private List<String> scheduleTimes = new ArrayList<>();

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public Medication() {
        // for JPA and service construction
    }

    @PrePersist
    void onCreate() {
        OffsetDateTime now = OffsetDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = OffsetDateTime.now();
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

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public BigDecimal getDoseMg() {
        return doseMg;
    }

    public void setDoseMg(BigDecimal doseMg) {
        this.doseMg = doseMg;
    }

    public Frequency getFrequency() {
        return frequency;
    }

    public void setFrequency(Frequency frequency) {
        this.frequency = frequency;
    }

    public List<String> getScheduleTimes() {
        return scheduleTimes;
    }

    public void setScheduleTimes(List<String> scheduleTimes) {
        this.scheduleTimes = (scheduleTimes == null) ? new ArrayList<>() : scheduleTimes;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
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

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
```

- [ ] **Step 5: Create the `DoseLog` entity**

Create `backend/src/main/java/com/heartcare/medication/model/DoseLog.java`:

```java
package com.heartcare.medication.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "dose_logs")
public class DoseLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "medication_id", nullable = false)
    private UUID medicationId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    @Column(name = "scheduled_time")
    private LocalTime scheduledTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private DoseStatus status;

    @Column(name = "logged_at", nullable = false)
    private OffsetDateTime loggedAt;

    @Column(name = "note")
    private String note;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public DoseLog() {
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

    public UUID getMedicationId() {
        return medicationId;
    }

    public void setMedicationId(UUID medicationId) {
        this.medicationId = medicationId;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public LocalDate getScheduledDate() {
        return scheduledDate;
    }

    public void setScheduledDate(LocalDate scheduledDate) {
        this.scheduledDate = scheduledDate;
    }

    public LocalTime getScheduledTime() {
        return scheduledTime;
    }

    public void setScheduledTime(LocalTime scheduledTime) {
        this.scheduledTime = scheduledTime;
    }

    public DoseStatus getStatus() {
        return status;
    }

    public void setStatus(DoseStatus status) {
        this.status = status;
    }

    public OffsetDateTime getLoggedAt() {
        return loggedAt;
    }

    public void setLoggedAt(OffsetDateTime loggedAt) {
        this.loggedAt = loggedAt;
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

- [ ] **Step 6: Create `MedicationRepository`**

Create `backend/src/main/java/com/heartcare/medication/MedicationRepository.java`:

```java
package com.heartcare.medication;

import com.heartcare.medication.model.Medication;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MedicationRepository extends JpaRepository<Medication, UUID> {

    Optional<Medication> findByIdAndUserId(UUID id, UUID userId);

    Optional<Medication> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    List<Medication> findByUserIdOrderByCreatedAtDesc(UUID userId);

    List<Medication> findByUserIdAndActiveTrueOrderByCreatedAtDesc(UUID userId);
}
```

- [ ] **Step 7: Create `DoseLogRepository`**

Create `backend/src/main/java/com/heartcare/medication/DoseLogRepository.java`. The history query binds three optional filters using the `:param IS NULL OR ...` idiom; `@Param` names are explicit so binding does not depend on `-parameters`.

```java
package com.heartcare.medication;

import com.heartcare.medication.model.DoseLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DoseLogRepository extends JpaRepository<DoseLog, UUID> {

    Optional<DoseLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT d FROM DoseLog d
            WHERE d.userId = :userId
              AND (:from IS NULL OR d.scheduledDate >= :from)
              AND (:to IS NULL OR d.scheduledDate <= :to)
              AND (:medicationId IS NULL OR d.medicationId = :medicationId)
            ORDER BY d.scheduledDate DESC, d.loggedAt DESC
            """)
    List<DoseLog> findHistory(@Param("userId") UUID userId,
                              @Param("from") LocalDate from,
                              @Param("to") LocalDate to,
                              @Param("medicationId") UUID medicationId);
}
```

- [ ] **Step 8: Write the repository round-trip test**

Create `backend/src/test/java/com/heartcare/medication/MedicationRepositoryTest.java`. Seeds a real `users` row via `JdbcTemplate` (FK constraint) without importing the auth module.

```java
package com.heartcare.medication;

import com.heartcare.AbstractIntegrationTest;
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
                "INSERT INTO users (id, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, id + "@example.com", "x", "Test User");
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
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `mvn test -Dtest=MedicationRepositoryTest`
Expected: PASS (2 tests). Flyway applies V3+V4 on the Testcontainer; JSONB, enum, `NUMERIC`, DATE/TIME/TIMESTAMPTZ round-trip. If Hibernate throws a schema-validation error, an entity column type doesn't match the SQL — align the entity to the migration (the migration is the source of truth).

- [ ] **Step 10: Commit**

```bash
git add backend/src/main/resources/db/migration/V3__create_medications.sql \
        backend/src/main/resources/db/migration/V4__create_dose_logs.sql \
        backend/src/main/java/com/heartcare/medication/ \
        backend/src/test/java/com/heartcare/medication/MedicationRepositoryTest.java
git commit -m "feat(backend): add medications + dose_logs tables, entities, repositories (Slice 3)"
```

---

### Task 2: Medication DTOs

**Files:**
- Create: `dto/MedicationRequest.java`, `dto/MedicationResponse.java`

**Interfaces:**
- Consumes: `Frequency` (Task 1).
- Produces:
  - `record MedicationRequest(String name, BigDecimal doseMg, Frequency frequency, List<String> scheduleTimes, Boolean active, UUID clientRecordId)` with Bean Validation.
  - `record MedicationResponse(String id, String name, BigDecimal doseMg, Frequency frequency, List<String> scheduleTimes, boolean active, String clientRecordId, OffsetDateTime createdAt, OffsetDateTime updatedAt)`.

- [ ] **Step 1: Create `MedicationRequest`**

Create `backend/src/main/java/com/heartcare/medication/dto/MedicationRequest.java`. `scheduleTimes` elements are validated with a container-element `@Pattern` (`HH:mm`, 24-hour). `active` is nullable (only meaningful on update; create forces `true` unless explicitly set).

```java
package com.heartcare.medication.dto;

import com.heartcare.medication.model.Frequency;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record MedicationRequest(
        @NotBlank(message = "name is required")
        @Size(max = 255, message = "name must be at most 255 characters")
        String name,

        @NotNull(message = "doseMg is required")
        @Positive(message = "doseMg must be greater than 0")
        BigDecimal doseMg,

        @NotNull(message = "frequency is required")
        Frequency frequency,

        List<@Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$",
                message = "scheduleTimes entries must be HH:mm (24-hour)") String> scheduleTimes,

        Boolean active,

        UUID clientRecordId) {
}
```

- [ ] **Step 2: Create `MedicationResponse`**

Create `backend/src/main/java/com/heartcare/medication/dto/MedicationResponse.java`:

```java
package com.heartcare.medication.dto;

import com.heartcare.medication.model.Frequency;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

public record MedicationResponse(
        String id,
        String name,
        BigDecimal doseMg,
        Frequency frequency,
        List<String> scheduleTimes,
        boolean active,
        String clientRecordId,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {
}
```

- [ ] **Step 3: Verify compilation**

Run: `mvn -q compile`
Expected: BUILD SUCCESS.

- [ ] **Step 4: Commit**

```bash
git add backend/src/main/java/com/heartcare/medication/dto/MedicationRequest.java \
        backend/src/main/java/com/heartcare/medication/dto/MedicationResponse.java
git commit -m "feat(backend): add medication request/response DTOs (Slice 3)"
```

---

### Task 3: `MedicationService` — create/list/update/deactivate

**Files:**
- Create: `MedicationService.java`
- Test: `MedicationServiceTest.java`

**Interfaces:**
- Consumes: `MedicationRepository` (Task 1), `Medication`/`Frequency` (Task 1), `MedicationRequest`/`MedicationResponse` (Task 2), `ResourceNotFoundException` (`common/exception`).
- Produces:
  - `MedicationResponse create(UUID userId, MedicationRequest req)` — idempotent on `clientRecordId`.
  - `List<MedicationResponse> list(UUID userId, boolean includeInactive)`.
  - `MedicationResponse update(UUID userId, UUID id, MedicationRequest req)` — 404 if not owned.
  - `MedicationResponse deactivate(UUID userId, UUID id)` — sets `active=false`; 404 if not owned.

- [ ] **Step 1: Write the failing unit tests**

Create `backend/src/test/java/com/heartcare/medication/MedicationServiceTest.java`:

```java
package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.dto.MedicationResponse;
import com.heartcare.medication.model.Frequency;
import com.heartcare.medication.model.Medication;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MedicationServiceTest {

    @Mock
    MedicationRepository repository;

    @InjectMocks
    MedicationService service;

    private final UUID userId = UUID.randomUUID();

    private MedicationRequest request(UUID clientRecordId, Boolean active) {
        return new MedicationRequest("Aspirin", new BigDecimal("100.00"),
                Frequency.BID, List.of("08:00", "20:00"), active, clientRecordId);
    }

    @Test
    void createSavesAndReturnsMedication() {
        when(repository.save(any(Medication.class))).thenAnswer(inv -> inv.getArgument(0));

        MedicationResponse response = service.create(userId, request(null, null));

        ArgumentCaptor<Medication> captor = ArgumentCaptor.forClass(Medication.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getUserId()).isEqualTo(userId);
        assertThat(captor.getValue().isActive()).isTrue();
        assertThat(captor.getValue().getScheduleTimes()).containsExactly("08:00", "20:00");
        assertThat(response.frequency()).isEqualTo(Frequency.BID);
    }

    @Test
    void createIsIdempotentOnClientRecordId() {
        UUID clientRecordId = UUID.randomUUID();
        Medication existing = new Medication();
        existing.setUserId(userId);
        existing.setName("Aspirin");
        existing.setDoseMg(new BigDecimal("100.00"));
        existing.setFrequency(Frequency.BID);
        when(repository.findByUserIdAndClientRecordId(userId, clientRecordId))
                .thenReturn(Optional.of(existing));

        MedicationResponse response = service.create(userId, request(clientRecordId, null));

        assertThat(response.name()).isEqualTo("Aspirin");
        verify(repository, never()).save(any());
    }

    @Test
    void listActiveOnlyByDefault() {
        when(repository.findByUserIdAndActiveTrueOrderByCreatedAtDesc(userId))
                .thenReturn(List.of());

        service.list(userId, false);

        verify(repository).findByUserIdAndActiveTrueOrderByCreatedAtDesc(userId);
        verify(repository, never()).findByUserIdOrderByCreatedAtDesc(any());
    }

    @Test
    void listIncludesInactiveWhenRequested() {
        when(repository.findByUserIdOrderByCreatedAtDesc(userId)).thenReturn(List.of());

        service.list(userId, true);

        verify(repository).findByUserIdOrderByCreatedAtDesc(userId);
    }

    @Test
    void updateReplacesFieldsOnOwnedMedication() {
        UUID id = UUID.randomUUID();
        Medication existing = new Medication();
        existing.setUserId(userId);
        existing.setName("Old");
        existing.setDoseMg(new BigDecimal("50.00"));
        existing.setFrequency(Frequency.ONCE_DAILY);
        when(repository.findByIdAndUserId(id, userId)).thenReturn(Optional.of(existing));
        when(repository.save(any(Medication.class))).thenAnswer(inv -> inv.getArgument(0));

        MedicationResponse response = service.update(userId, id, request(null, null));

        assertThat(response.name()).isEqualTo("Aspirin");
        assertThat(response.frequency()).isEqualTo(Frequency.BID);
        verify(repository).save(existing);
    }

    @Test
    void updateUnknownMedicationThrowsNotFound() {
        UUID id = UUID.randomUUID();
        when(repository.findByIdAndUserId(id, userId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(userId, id, request(null, null)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void deactivateSetsActiveFalse() {
        UUID id = UUID.randomUUID();
        Medication existing = new Medication();
        existing.setUserId(userId);
        existing.setName("Aspirin");
        existing.setDoseMg(new BigDecimal("100.00"));
        existing.setFrequency(Frequency.BID);
        existing.setActive(true);
        when(repository.findByIdAndUserId(id, userId)).thenReturn(Optional.of(existing));
        when(repository.save(any(Medication.class))).thenAnswer(inv -> inv.getArgument(0));

        MedicationResponse response = service.deactivate(userId, id);

        assertThat(response.active()).isFalse();
        assertThat(existing.isActive()).isFalse();
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mvn test -Dtest=MedicationServiceTest`
Expected: FAIL — compilation error (`MedicationService` does not exist).

- [ ] **Step 3: Implement `MedicationService`**

Create `backend/src/main/java/com/heartcare/medication/MedicationService.java`. `clientRecordId` is only assigned on create (it identifies the created record), never overwritten on update.

```java
package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.dto.MedicationResponse;
import com.heartcare.medication.model.Medication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class MedicationService {

    private final MedicationRepository repository;

    public MedicationService(MedicationRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public MedicationResponse create(UUID userId, MedicationRequest request) {
        if (request.clientRecordId() != null) {
            var existing = repository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }
        Medication medication = new Medication();
        medication.setUserId(userId);
        medication.setClientRecordId(request.clientRecordId());
        applyEditableFields(medication, request);
        medication.setActive(request.active() == null || request.active());
        return toResponse(repository.save(medication));
    }

    @Transactional(readOnly = true)
    public List<MedicationResponse> list(UUID userId, boolean includeInactive) {
        List<Medication> medications = includeInactive
                ? repository.findByUserIdOrderByCreatedAtDesc(userId)
                : repository.findByUserIdAndActiveTrueOrderByCreatedAtDesc(userId);
        return medications.stream().map(this::toResponse).toList();
    }

    @Transactional
    public MedicationResponse update(UUID userId, UUID id, MedicationRequest request) {
        Medication medication = getOwned(userId, id);
        applyEditableFields(medication, request);
        if (request.active() != null) {
            medication.setActive(request.active());
        }
        return toResponse(repository.save(medication));
    }

    @Transactional
    public MedicationResponse deactivate(UUID userId, UUID id) {
        Medication medication = getOwned(userId, id);
        medication.setActive(false);
        return toResponse(repository.save(medication));
    }

    private Medication getOwned(UUID userId, UUID id) {
        return repository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medication not found"));
    }

    private void applyEditableFields(Medication medication, MedicationRequest request) {
        medication.setName(request.name());
        medication.setDoseMg(request.doseMg());
        medication.setFrequency(request.frequency());
        medication.setScheduleTimes(request.scheduleTimes() == null
                ? new ArrayList<>() : new ArrayList<>(request.scheduleTimes()));
    }

    private MedicationResponse toResponse(Medication m) {
        return new MedicationResponse(
                m.getId().toString(),
                m.getName(),
                m.getDoseMg(),
                m.getFrequency(),
                m.getScheduleTimes(),
                m.isActive(),
                m.getClientRecordId() == null ? null : m.getClientRecordId().toString(),
                m.getCreatedAt(),
                m.getUpdatedAt());
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mvn test -Dtest=MedicationServiceTest`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/heartcare/medication/MedicationService.java \
        backend/src/test/java/com/heartcare/medication/MedicationServiceTest.java
git commit -m "feat(backend): add MedicationService with unit tests (Slice 3)"
```

---

### Task 4: `MedicationController` + malformed-body handler

**Files:**
- Create: `MedicationController.java`
- Modify: `common/exception/GlobalExceptionHandler.java`
- Test: `MedicationControllerIntegrationTest.java`

**Interfaces:**
- Consumes: `MedicationService` (Task 3), `ApiResponse` (`common/response`), `UserPrincipal` (`common/security`), `MedicationRequest`/`MedicationResponse` (Task 2).
- Produces: `POST /api/v1/medications`, `GET /api/v1/medications`, `PUT /api/v1/medications/{id}`, `DELETE /api/v1/medications/{id}`, each returning `ApiResponse<...>`. Plus a 400 response for unreadable/invalid-enum bodies.

- [ ] **Step 1: Write the failing integration tests**

Create `backend/src/test/java/com/heartcare/medication/MedicationControllerIntegrationTest.java`. Registers a user through the real auth endpoint to obtain a token (black-box; no auth classes imported).

```java
package com.heartcare.medication;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class MedicationControllerIntegrationTest extends AbstractIntegrationTest {

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

    private static final String ASPIRIN = """
            { "name": "Aspirin", "doseMg": 100, "frequency": "BID",
              "scheduleTimes": ["08:00", "20:00"] }
            """;

    @Test
    void createWithoutTokenReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/medications")
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void createThenListReturnsMedication() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Aspirin"))
                .andExpect(jsonPath("$.data.frequency").value("BID"))
                .andExpect(jsonPath("$.data.scheduleTimes[0]").value("08:00"))
                .andExpect(jsonPath("$.data.active").value(true));

        mockMvc.perform(get("/api/v1/medications")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].name").value("Aspirin"));
    }

    @Test
    void createIsIdempotentOnClientRecordId() throws Exception {
        String token = registerAndGetToken();
        String clientRecordId = UUID.randomUUID().toString();
        String body = """
                { "name": "Aspirin", "doseMg": 100, "frequency": "BID",
                  "scheduleTimes": ["08:00"], "clientRecordId": "%s" }
                """.formatted(clientRecordId);

        mockMvc.perform(post("/api/v1/medications").header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/medications").header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/medications").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void updateChangesFields() throws Exception {
        String token = registerAndGetToken();
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andReturn();
        String id = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        mockMvc.perform(put("/api/v1/medications/" + id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin EC\", \"doseMg\": 81, \"frequency\": \"ONCE_DAILY\", \"scheduleTimes\": [\"09:00\"] }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Aspirin EC"))
                .andExpect(jsonPath("$.data.frequency").value("ONCE_DAILY"));
    }

    @Test
    void deleteDeactivatesAndHidesFromDefaultList() throws Exception {
        String token = registerAndGetToken();
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andReturn();
        String id = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        mockMvc.perform(delete("/api/v1/medications/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.active").value(false));

        mockMvc.perform(get("/api/v1/medications")
                        .header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(0));

        mockMvc.perform(get("/api/v1/medications?includeInactive=true")
                        .header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void accessingOthersMedicationReturns404() throws Exception {
        String tokenA = registerAndGetToken();
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andReturn();
        String id = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        String tokenB = registerAndGetToken();
        mockMvc.perform(delete("/api/v1/medications/" + id)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void invalidFrequencyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": 100, \"frequency\": \"HOURLY\" }"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void negativeDoseReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": -5, \"frequency\": \"BID\" }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidScheduleTimeReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": 100, \"frequency\": \"BID\", \"scheduleTimes\": [\"25:00\"] }"))
                .andExpect(status().isBadRequest());
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mvn test -Dtest=MedicationControllerIntegrationTest`
Expected: FAIL — compilation error (`MedicationController` missing) / 404s.

- [ ] **Step 3: Add the malformed-body handler to `GlobalExceptionHandler`**

An unknown enum value (e.g. `"frequency": "HOURLY"`) makes Jackson throw `HttpMessageNotReadableException`, which currently falls through to the generic 500 handler. Add a handler that returns 400. Edit `backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java` — add the import and the new method:

Add import (with the other `org.springframework` imports):
```java
import org.springframework.http.converter.HttpMessageNotReadableException;
```

Add this method (e.g. directly after `handleValidation`):
```java
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleUnreadable(HttpMessageNotReadableException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error("Malformed or invalid request body"));
    }
```

- [ ] **Step 4: Implement `MedicationController`**

Create `backend/src/main/java/com/heartcare/medication/MedicationController.java`:

```java
package com.heartcare.medication;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.dto.MedicationResponse;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/medications")
public class MedicationController {

    private final MedicationService medicationService;

    public MedicationController(MedicationService medicationService) {
        this.medicationService = medicationService;
    }

    @PostMapping
    public ApiResponse<MedicationResponse> create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody MedicationRequest request) {
        return ApiResponse.ok(medicationService.create(principal.userId(), request), "Medication created");
    }

    @GetMapping
    public ApiResponse<List<MedicationResponse>> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return ApiResponse.ok(medicationService.list(principal.userId(), includeInactive));
    }

    @PutMapping("/{id}")
    public ApiResponse<MedicationResponse> update(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID id,
            @Valid @RequestBody MedicationRequest request) {
        return ApiResponse.ok(medicationService.update(principal.userId(), id, request), "Medication updated");
    }

    @DeleteMapping("/{id}")
    public ApiResponse<MedicationResponse> deactivate(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID id) {
        return ApiResponse.ok(medicationService.deactivate(principal.userId(), id), "Medication deactivated");
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `mvn test -Dtest=MedicationControllerIntegrationTest`
Expected: PASS (9 tests). Requires Docker.

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/heartcare/medication/MedicationController.java \
        backend/src/main/java/com/heartcare/common/exception/GlobalExceptionHandler.java \
        backend/src/test/java/com/heartcare/medication/MedicationControllerIntegrationTest.java
git commit -m "feat(backend): add medication CRUD endpoints + 400 on malformed body (Slice 3)"
```

---

### Task 5: Dose-log DTOs

**Files:**
- Create: `dto/DoseLogRequest.java`, `dto/DoseLogResponse.java`

**Interfaces:**
- Consumes: `DoseStatus` (Task 1).
- Produces:
  - `record DoseLogRequest(DoseStatus status, LocalDate scheduledDate, LocalTime scheduledTime, OffsetDateTime loggedAt, String note, UUID clientRecordId)` with validation.
  - `record DoseLogResponse(String id, String medicationId, LocalDate scheduledDate, LocalTime scheduledTime, DoseStatus status, OffsetDateTime loggedAt, String note, String clientRecordId, OffsetDateTime createdAt)`.

- [ ] **Step 1: Create `DoseLogRequest`**

Create `backend/src/main/java/com/heartcare/medication/dto/DoseLogRequest.java`. `loggedAt` is optional (the service defaults it to now when omitted); `scheduledTime` and `note` are optional.

```java
package com.heartcare.medication.dto;

import com.heartcare.medication.model.DoseStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

public record DoseLogRequest(
        @NotNull(message = "status is required")
        DoseStatus status,

        @NotNull(message = "scheduledDate is required")
        LocalDate scheduledDate,

        LocalTime scheduledTime,

        OffsetDateTime loggedAt,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        UUID clientRecordId) {
}
```

- [ ] **Step 2: Create `DoseLogResponse`**

Create `backend/src/main/java/com/heartcare/medication/dto/DoseLogResponse.java`:

```java
package com.heartcare.medication.dto;

import com.heartcare.medication.model.DoseStatus;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;

public record DoseLogResponse(
        String id,
        String medicationId,
        LocalDate scheduledDate,
        LocalTime scheduledTime,
        DoseStatus status,
        OffsetDateTime loggedAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
```

- [ ] **Step 3: Verify compilation**

Run: `mvn -q compile`
Expected: BUILD SUCCESS.

- [ ] **Step 4: Commit**

```bash
git add backend/src/main/java/com/heartcare/medication/dto/DoseLogRequest.java \
        backend/src/main/java/com/heartcare/medication/dto/DoseLogResponse.java
git commit -m "feat(backend): add dose-log request/response DTOs (Slice 3)"
```

---

### Task 6: `DoseLogService` — log + history

**Files:**
- Create: `DoseLogService.java`
- Test: `DoseLogServiceTest.java`

**Interfaces:**
- Consumes: `DoseLogRepository` + `MedicationRepository` (Task 1), `DoseLog`/`DoseStatus` (Task 1), `DoseLogRequest`/`DoseLogResponse` (Task 5), `ResourceNotFoundException` (`common/exception`).
- Produces:
  - `DoseLogResponse log(UUID userId, UUID medicationId, DoseLogRequest req)` — verifies the medication is owned (404 otherwise); idempotent on `clientRecordId`; defaults `loggedAt` to now when null.
  - `List<DoseLogResponse> history(UUID userId, LocalDate from, LocalDate to, UUID medicationId)`.

- [ ] **Step 1: Write the failing unit tests**

Create `backend/src/test/java/com/heartcare/medication/DoseLogServiceTest.java`:

```java
package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.DoseLogResponse;
import com.heartcare.medication.model.DoseLog;
import com.heartcare.medication.model.DoseStatus;
import com.heartcare.medication.model.Medication;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DoseLogServiceTest {

    @Mock
    DoseLogRepository doseLogRepository;

    @Mock
    MedicationRepository medicationRepository;

    @InjectMocks
    DoseLogService service;

    private final UUID userId = UUID.randomUUID();
    private final UUID medicationId = UUID.randomUUID();

    private DoseLogRequest request(UUID clientRecordId) {
        return new DoseLogRequest(DoseStatus.TAKEN, LocalDate.of(2026, 7, 10),
                LocalTime.of(8, 0), OffsetDateTime.parse("2026-07-10T08:05:00Z"), "with food", clientRecordId);
    }

    @Test
    void logCreatesDoseAgainstOwnedMedication() {
        when(medicationRepository.findByIdAndUserId(medicationId, userId))
                .thenReturn(Optional.of(new Medication()));
        when(doseLogRepository.save(any(DoseLog.class))).thenAnswer(inv -> inv.getArgument(0));

        DoseLogResponse response = service.log(userId, medicationId, request(null));

        ArgumentCaptor<DoseLog> captor = ArgumentCaptor.forClass(DoseLog.class);
        verify(doseLogRepository).save(captor.capture());
        assertThat(captor.getValue().getMedicationId()).isEqualTo(medicationId);
        assertThat(captor.getValue().getUserId()).isEqualTo(userId);
        assertThat(captor.getValue().getStatus()).isEqualTo(DoseStatus.TAKEN);
        assertThat(response.status()).isEqualTo(DoseStatus.TAKEN);
        assertThat(response.note()).isEqualTo("with food");
    }

    @Test
    void logDefaultsLoggedAtWhenNull() {
        when(medicationRepository.findByIdAndUserId(medicationId, userId))
                .thenReturn(Optional.of(new Medication()));
        when(doseLogRepository.save(any(DoseLog.class))).thenAnswer(inv -> inv.getArgument(0));
        DoseLogRequest req = new DoseLogRequest(DoseStatus.SKIPPED, LocalDate.of(2026, 7, 10),
                null, null, null, null);

        DoseLogResponse response = service.log(userId, medicationId, req);

        assertThat(response.loggedAt()).isNotNull();
    }

    @Test
    void logAgainstUnknownMedicationThrowsNotFound() {
        when(medicationRepository.findByIdAndUserId(medicationId, userId))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.log(userId, medicationId, request(null)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(doseLogRepository, never()).save(any());
    }

    @Test
    void logIsIdempotentOnClientRecordId() {
        UUID clientRecordId = UUID.randomUUID();
        when(medicationRepository.findByIdAndUserId(medicationId, userId))
                .thenReturn(Optional.of(new Medication()));
        DoseLog existing = new DoseLog();
        existing.setMedicationId(medicationId);
        existing.setUserId(userId);
        existing.setStatus(DoseStatus.TAKEN);
        existing.setScheduledDate(LocalDate.of(2026, 7, 10));
        existing.setLoggedAt(OffsetDateTime.parse("2026-07-10T08:05:00Z"));
        when(doseLogRepository.findByUserIdAndClientRecordId(userId, clientRecordId))
                .thenReturn(Optional.of(existing));

        DoseLogResponse response = service.log(userId, medicationId, request(clientRecordId));

        assertThat(response.status()).isEqualTo(DoseStatus.TAKEN);
        verify(doseLogRepository, never()).save(any());
    }

    @Test
    void historyDelegatesToRepositoryWithFilters() {
        LocalDate from = LocalDate.of(2026, 7, 1);
        LocalDate to = LocalDate.of(2026, 7, 31);
        when(doseLogRepository.findHistory(userId, from, to, medicationId)).thenReturn(List.of());

        service.history(userId, from, to, medicationId);

        verify(doseLogRepository).findHistory(eq(userId), eq(from), eq(to), eq(medicationId));
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mvn test -Dtest=DoseLogServiceTest`
Expected: FAIL — compilation error (`DoseLogService` does not exist).

- [ ] **Step 3: Implement `DoseLogService`**

Create `backend/src/main/java/com/heartcare/medication/DoseLogService.java`:

```java
package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.DoseLogResponse;
import com.heartcare.medication.model.DoseLog;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

@Service
public class DoseLogService {

    private final DoseLogRepository doseLogRepository;
    private final MedicationRepository medicationRepository;

    public DoseLogService(DoseLogRepository doseLogRepository, MedicationRepository medicationRepository) {
        this.doseLogRepository = doseLogRepository;
        this.medicationRepository = medicationRepository;
    }

    @Transactional
    public DoseLogResponse log(UUID userId, UUID medicationId, DoseLogRequest request) {
        medicationRepository.findByIdAndUserId(medicationId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medication not found"));

        if (request.clientRecordId() != null) {
            var existing = doseLogRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        DoseLog dose = new DoseLog();
        dose.setMedicationId(medicationId);
        dose.setUserId(userId);
        dose.setScheduledDate(request.scheduledDate());
        dose.setScheduledTime(request.scheduledTime());
        dose.setStatus(request.status());
        dose.setLoggedAt(request.loggedAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.loggedAt());
        dose.setNote(request.note());
        dose.setClientRecordId(request.clientRecordId());
        return toResponse(doseLogRepository.save(dose));
    }

    @Transactional(readOnly = true)
    public List<DoseLogResponse> history(UUID userId, LocalDate from, LocalDate to, UUID medicationId) {
        return doseLogRepository.findHistory(userId, from, to, medicationId)
                .stream().map(this::toResponse).toList();
    }

    private DoseLogResponse toResponse(DoseLog d) {
        return new DoseLogResponse(
                d.getId() == null ? null : d.getId().toString(),
                d.getMedicationId().toString(),
                d.getScheduledDate(),
                d.getScheduledTime(),
                d.getStatus(),
                d.getLoggedAt(),
                d.getNote(),
                d.getClientRecordId() == null ? null : d.getClientRecordId().toString(),
                d.getCreatedAt());
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mvn test -Dtest=DoseLogServiceTest`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/heartcare/medication/DoseLogService.java \
        backend/src/test/java/com/heartcare/medication/DoseLogServiceTest.java
git commit -m "feat(backend): add DoseLogService with unit tests (Slice 3)"
```

---

### Task 7: `DoseLogController` + full-suite check

**Files:**
- Create: `DoseLogController.java`
- Test: `DoseLogControllerIntegrationTest.java`

**Interfaces:**
- Consumes: `DoseLogService` (Task 6), `ApiResponse`, `UserPrincipal`, `DoseLogRequest`/`DoseLogResponse` (Task 5).
- Produces: `POST /api/v1/medications/{medicationId}/doses`, `GET /api/v1/dose-logs?from=&to=&medicationId=`, each returning `ApiResponse<...>`.

- [ ] **Step 1: Write the failing integration tests**

Create `backend/src/test/java/com/heartcare/medication/DoseLogControllerIntegrationTest.java`:

```java
package com.heartcare.medication;

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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class DoseLogControllerIntegrationTest extends AbstractIntegrationTest {

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

    private String createMedication(String token) throws Exception {
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": 100, \"frequency\": \"BID\", \"scheduleTimes\": [\"08:00\"] }"))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");
    }

    @Test
    void logThenHistoryReturnsDose() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);

        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\", \"scheduledDate\": \"2026-07-10\", \"scheduledTime\": \"08:00\", \"note\": \"with food\" }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("TAKEN"))
                .andExpect(jsonPath("$.data.medicationId").value(medId));

        mockMvc.perform(get("/api/v1/dose-logs")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].status").value("TAKEN"))
                .andExpect(jsonPath("$.data[0].note").value("with food"));
    }

    @Test
    void historyFiltersByDateRange() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        logDose(token, medId, "2026-07-05");
        logDose(token, medId, "2026-07-20");

        mockMvc.perform(get("/api/v1/dose-logs?from=2026-07-10&to=2026-07-31")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].scheduledDate").value("2026-07-20"));
    }

    @Test
    void historyFiltersByMedicationId() throws Exception {
        String token = registerAndGetToken();
        String medA = createMedication(token);
        String medB = createMedication(token);
        logDose(token, medA, "2026-07-10");
        logDose(token, medB, "2026-07-10");

        mockMvc.perform(get("/api/v1/dose-logs?medicationId=" + medA)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].medicationId").value(medA));
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        String crid = UUID.randomUUID().toString();
        String body = "{ \"status\": \"TAKEN\", \"scheduledDate\": \"2026-07-10\", \"clientRecordId\": \"%s\" }".formatted(crid);

        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                .header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                .header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/dose-logs").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void invalidStatusReturns400() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"LATER\", \"scheduledDate\": \"2026-07-10\" }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void missingScheduledDateReturns400() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\" }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void loggingAgainstOthersMedicationReturns404() throws Exception {
        String tokenA = registerAndGetToken();
        String medId = createMedication(tokenA);
        String tokenB = registerAndGetToken();

        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + tokenB)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\", \"scheduledDate\": \"2026-07-10\" }"))
                .andExpect(status().isNotFound());
    }

    private void logDose(String token, String medId, String date) throws Exception {
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\", \"scheduledDate\": \"%s\" }".formatted(date)))
                .andExpect(status().isOk());
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mvn test -Dtest=DoseLogControllerIntegrationTest`
Expected: FAIL — compilation error (`DoseLogController` missing) / 404s on the dose routes.

- [ ] **Step 3: Implement `DoseLogController`**

Create `backend/src/main/java/com/heartcare/medication/DoseLogController.java`. `from`/`to` parse as ISO dates.

```java
package com.heartcare.medication;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.DoseLogResponse;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class DoseLogController {

    private final DoseLogService doseLogService;

    public DoseLogController(DoseLogService doseLogService) {
        this.doseLogService = doseLogService;
    }

    @PostMapping("/medications/{medicationId}/doses")
    public ApiResponse<DoseLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID medicationId,
            @Valid @RequestBody DoseLogRequest request) {
        return ApiResponse.ok(doseLogService.log(principal.userId(), medicationId, request), "Dose logged");
    }

    @GetMapping("/dose-logs")
    public ApiResponse<List<DoseLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) UUID medicationId) {
        return ApiResponse.ok(doseLogService.history(principal.userId(), from, to, medicationId));
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mvn test -Dtest=DoseLogControllerIntegrationTest`
Expected: PASS (7 tests). Requires Docker.

- [ ] **Step 5: Run the full suite to confirm no regressions**

Run: `mvn test`
Expected: PASS — all Slice 1/2 tests plus the new Slice 3 tests are green.

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/heartcare/medication/DoseLogController.java \
        backend/src/test/java/com/heartcare/medication/DoseLogControllerIntegrationTest.java
git commit -m "feat(backend): add dose-log endpoints with integration tests (Slice 3)"
```

---

### Task 8: Documentation

**Files:**
- Modify: `backend/README.md`, `backend/docs/API.md`, `backend/docs/DATABASE.md`

**Interfaces:** none (docs only).

- [ ] **Step 1: Update the README build-progress table**

In `backend/README.md`, change the Slice 3 row to ✅:

```markdown
| 3 | Medications & dose logs (CRUD + Taken/Missed/Skipped logging, JSONB schedule) | ✅ Done |
```

- [ ] **Step 2: Add the endpoints to `API.md`**

Append a "Medications & Dose Logs" section to `backend/docs/API.md`, matching the existing formatting. Document all six endpoints, the `ApiResponse` envelope, and the `client_record_id` idempotency behavior:

```markdown
## Medications & Dose Logs

All endpoints require `Authorization: Bearer <JWT>`. Base path `/api/v1`.
Operations on another user's records return `404`. `POST` creates are idempotent
on `clientRecordId`: repeating a create with the same value returns the existing row.

### POST /medications
Create a medication. Body: `{ name, doseMg, frequency, scheduleTimes[], active?, clientRecordId? }`
where `frequency ∈ {ONCE_DAILY, BID, TID, CUSTOM}` and each `scheduleTimes` entry is `HH:mm`.
Validation: `name` required; `doseMg` > 0; `frequency` required. Invalid → `400`.

### GET /medications?includeInactive=false
List the caller's medications, newest first. `includeInactive=true` also returns deactivated ones.

### PUT /medications/{id}
Full-replace of `name, doseMg, frequency, scheduleTimes, active`. `404` if not owned.

### DELETE /medications/{id}
Soft-deactivate (sets `active:false`; dose history is preserved). Returns the deactivated medication.

### POST /medications/{id}/doses
Log a dose. Body: `{ status, scheduledDate, scheduledTime?, loggedAt?, note?, clientRecordId? }`
where `status ∈ {TAKEN, MISSED, SKIPPED}`. `scheduledDate` (`YYYY-MM-DD`) required; `loggedAt`
defaults to now when omitted. `404` if the medication is not owned.

### GET /dose-logs?from=&to=&medicationId=
Return the caller's dose history, newest first. All filters optional: `from`/`to` bound
`scheduledDate` (inclusive, `YYYY-MM-DD`); `medicationId` narrows to one medication.
```

- [ ] **Step 3: Add the tables to `DATABASE.md`**

Append `V3`/`V4` entries to `backend/docs/DATABASE.md`, matching the existing table-description style:

```markdown
### V3 — `create_medications`
`medications` table: one row per medication (many per patient). `user_id` FK → `users(id)`
`ON DELETE CASCADE`. `schedule_times` is a JSONB array of `HH:mm` strings. Soft-deactivated
via `active=false` (never hard-deleted, to preserve dose history). `client_record_id` is a
per-user sync idempotency key (`UNIQUE (user_id, client_record_id)`).

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | app-assigned |
| user_id | UUID | FK → `users(id)` `ON DELETE CASCADE` |
| name | VARCHAR(255) NOT NULL | |
| dose_mg | NUMERIC(8,2) NOT NULL | > 0 |
| frequency | VARCHAR(20) NOT NULL | `ONCE_DAILY`/`BID`/`TID`/`CUSTOM` |
| schedule_times | JSONB NOT NULL | default `[]`; array of `HH:mm` |
| active | BOOLEAN NOT NULL | default `true` |
| client_record_id | UUID | unique per `user_id` |
| created_at / updated_at | TIMESTAMPTZ NOT NULL | default `now()` |

### V4 — `create_dose_logs`
`dose_logs` table: append-only event log of dose actions (many per medication). `medication_id`
FK → `medications(id)` and `user_id` FK → `users(id)`, both `ON DELETE CASCADE`. Rows are written
by the device when the patient logs a dose.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | app-assigned |
| medication_id | UUID | FK → `medications(id)` `ON DELETE CASCADE` |
| user_id | UUID | FK → `users(id)` `ON DELETE CASCADE` |
| scheduled_date | DATE NOT NULL | the day the dose was due |
| scheduled_time | TIME | nullable (ad-hoc dose) |
| status | VARCHAR(10) NOT NULL | `TAKEN`/`MISSED`/`SKIPPED` |
| logged_at | TIMESTAMPTZ NOT NULL | actual action time |
| note | TEXT | nullable |
| client_record_id | UUID | unique per `user_id` |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |
```

- [ ] **Step 4: Commit**

```bash
git add backend/README.md backend/docs/API.md backend/docs/DATABASE.md
git commit -m "docs(backend): document Slice 3 medication endpoints and schema"
```

---

## Verification (end of slice)

- [ ] `mvn test` from `backend/` is fully green (Slice 1 + 2 + 3, Docker running).
- [ ] `mvn spring-boot:run` boots and Flyway applies `V3` then `V4` on top of `V2` (manual smoke, optional).
- [ ] End-to-end by hand (optional): register → add medication → log a TAKEN dose → `GET /dose-logs` shows it; a second user gets 404 on the first user's medication; re-POST with the same `clientRecordId` yields one row.
- [ ] `git log --oneline` shows the Slice 3 commits; working tree clean.
- [ ] Re-index the graph (`detect_changes()` / `index_repository`) so the new `medication` package is searchable.

## Notes on likely failure points

- **Hibernate schema-validation error on boot/tests:** an entity column type doesn't match the migration. Most likely `dose_mg` precision/scale, an enum column `length`, or a `@Column(name=...)` typo. The migration is the source of truth — align the entity to it.
- **JSONB mapping error (`scheduleTimes` won't serialize):** ensure `@JdbcTypeCode(SqlTypes.JSON)` is on `scheduleTimes`, imported from `org.hibernate.annotations` / `org.hibernate.type`. No extra Maven dependency needed.
- **Invalid-enum returns 500 instead of 400:** the `HttpMessageNotReadableException` handler from Task 4 Step 3 must be present; without it, a bad `frequency`/`status` string falls through to the generic 500 handler.
- **`findHistory` null-filter binding:** keep the `@Param` names and the `:x IS NULL OR ...` idiom; removing `@Param` can break binding if `-parameters` is not on the compiler.
- **Idempotency unique-constraint violation:** the service must `findByUserIdAndClientRecordId` before insert and return the existing row; a blind insert of a repeated `clientRecordId` will hit `uq_*_user_client_record`. Also do not overwrite `clientRecordId` on update.
- **Duplicate-key on `client_record_id = NULL`:** Postgres treats `NULL`s as distinct, so multiple rows with a null `client_record_id` do not violate the unique constraint — server-originated rows without a client id are fine.
```