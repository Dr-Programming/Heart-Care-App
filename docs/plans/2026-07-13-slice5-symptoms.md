# Slice 5 — Symptom Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a daily symptom check-in feature: a patient logs one composite check-in, the server computes an authoritative per-symptom + overall severity assessment, and the patient reads back check-in history filtered by date.

**Architecture:** A new standalone package-by-feature module `com.heartcare.symptoms` mirroring the Slice 4 vitals feature (Controller → Service → Repository → JPA entity with JSONB payload). One `symptom_logs` row = one check-in; symptom fields live in a JSONB `data` map; the server computes a `Severity` assessment stored as a JSONB snapshot plus a queryable `overall_severity` column. Append-only, `client_record_id` idempotent, patient-self-scoped. **No cross-feature dependencies.**

**Tech Stack:** Java 21 · Spring Boot 4.1.0 · Spring Data JPA / Hibernate 7 · PostgreSQL 16 · Flyway · JUnit 5 · Mockito · Testcontainers · AssertJ.

## Global Constraints

- **Spec:** `docs/design/2026-07-13-symptoms-design.md` is the source of truth. This plan implements it.
- **`ddl-auto=validate`** — the entity MUST match the `V6` migration exactly (column names, types, nullability), or the context fails to start.
- **Commits: NO AI co-author trailer.** Author is Prince Khakhariya. Never add a `Co-Authored-By: Claude` line.
- **Migration column names:** PostgreSQL reserved-word caution — `data` and `assessment` are non-reserved and safe as column names (contrast `vital_values`, renamed because `values` is reserved).
- **All endpoints require a Bearer JWT** and are scoped to `UserPrincipal.userId()`. `SecurityConfig` already gates everything except register/login with `.anyRequest().authenticated()`; new `/symptoms` routes are protected automatically — **no SecurityConfig change**.
- **Responses use `com.heartcare.common.response.ApiResponse`**: `ApiResponse.ok(data)`, `ApiResponse.ok(data, msg)`, `ApiResponse.error(msg)`.
- **Validation failures throw `com.heartcare.common.exception.BadRequestException`** (already mapped to HTTP 400 by `GlobalExceptionHandler`). Bean-validation (`@Valid`/`@NotNull`/`@Size`) and malformed JSON also already map to 400.
- **UTC everywhere:** default timestamps via `OffsetDateTime.now(ZoneOffset.UTC)`; date filters bucket by UTC day using the half-open `[fromTs, toTs)` pattern established in `VitalsService`.
- **Severity ordering:** the `Severity` enum's declaration order (`NONE, MONITOR, URGENT, EMERGENCY`) IS the ordinal ranking; "overall = max" relies on `Comparator.naturalOrder()` over enum ordinals. Do not reorder constants.

**Reference implementations (read before starting — this feature is a near-clone):**
- `backend/src/main/resources/db/migration/V5__create_vitals_logs.sql`
- `backend/src/main/java/com/heartcare/vitals/model/VitalLog.java`, `VitalsRepository.java`, `VitalsService.java`, `VitalsController.java`, `VitalThresholds.java`, `dto/VitalLogRequest.java`, `dto/VitalLogResponse.java`
- `backend/src/test/java/com/heartcare/vitals/VitalsRepositoryTest.java`, `VitalsServiceTest.java`, `VitalsControllerIntegrationTest.java`
- `backend/src/test/java/com/heartcare/AbstractIntegrationTest.java`

---

### Task 1: Migration, `Severity` enum, `SymptomLog` entity, repository, round-trip test

Establishes the persistence layer and proves nested JSONB `Map<String, Object>` round-trips on real Postgres under `ddl-auto=validate`.

**Files:**
- Create: `backend/src/main/resources/db/migration/V6__create_symptom_logs.sql`
- Create: `backend/src/main/java/com/heartcare/symptoms/model/Severity.java`
- Create: `backend/src/main/java/com/heartcare/symptoms/model/SymptomLog.java`
- Create: `backend/src/main/java/com/heartcare/symptoms/SymptomsRepository.java`
- Test: `backend/src/test/java/com/heartcare/symptoms/SymptomsRepositoryTest.java`

**Interfaces:**
- Produces:
  - `enum Severity { NONE, MONITOR, URGENT, EMERGENCY }` (package `com.heartcare.symptoms.model`).
  - `class SymptomLog` (entity) with getters/setters: `UUID getId()`, `UUID getUserId()/setUserId`, `Map<String,Object> getData()/setData`, `Map<String,Object> getAssessment()/setAssessment`, `Severity getOverallSeverity()/setOverallSeverity`, `OffsetDateTime getMeasuredAt()/setMeasuredAt`, `String getNote()/setNote`, `UUID getClientRecordId()/setClientRecordId`, `OffsetDateTime getCreatedAt()`.
  - `interface SymptomsRepository extends JpaRepository<SymptomLog, UUID>` with `Optional<SymptomLog> findByUserIdAndClientRecordId(UUID, UUID)` and `List<SymptomLog> findHistory(UUID userId, OffsetDateTime from, OffsetDateTime to)`.

- [ ] **Step 1: Write the migration**

Create `backend/src/main/resources/db/migration/V6__create_symptom_logs.sql`:

```sql
-- One row per daily symptom check-in. `data` holds the patient's entered fields;
-- `assessment` holds the server-computed {overall, symptoms} severity snapshot.
CREATE TABLE symptom_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    data              JSONB NOT NULL,
    assessment        JSONB NOT NULL,
    overall_severity  VARCHAR(20) NOT NULL,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_symptom_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_symptom_user_measured ON symptom_logs(user_id, measured_at);
CREATE INDEX idx_symptom_user_severity ON symptom_logs(user_id, overall_severity);
```

- [ ] **Step 2: Write the `Severity` enum**

Create `backend/src/main/java/com/heartcare/symptoms/model/Severity.java`:

```java
package com.heartcare.symptoms.model;

/**
 * Clinical urgency of a symptom or check-in (FR-SYM-010). Declaration order IS the
 * ranking: NONE &lt; MONITOR &lt; URGENT &lt; EMERGENCY. "Overall" severity is the max
 * (via Comparator.naturalOrder() over ordinals). Do not reorder these constants.
 */
public enum Severity {
    NONE,
    MONITOR,
    URGENT,
    EMERGENCY
}
```

- [ ] **Step 3: Write the `SymptomLog` entity**

Create `backend/src/main/java/com/heartcare/symptoms/model/SymptomLog.java` (mirrors `VitalLog`, with two JSONB maps and a `Severity` column):

```java
package com.heartcare.symptoms.model;

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

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "symptom_logs")
public class SymptomLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "data", nullable = false)
    private Map<String, Object> data = new HashMap<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "assessment", nullable = false)
    private Map<String, Object> assessment = new HashMap<>();

    @Enumerated(EnumType.STRING)
    @Column(name = "overall_severity", nullable = false, length = 20)
    private Severity overallSeverity;

    @Column(name = "measured_at", nullable = false)
    private OffsetDateTime measuredAt;

    @Column(name = "note")
    private String note;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public SymptomLog() {
        // for JPA and service construction
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now(ZoneOffset.UTC);
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

    public Map<String, Object> getData() {
        return data;
    }

    public void setData(Map<String, Object> data) {
        this.data = (data == null) ? new HashMap<>() : data;
    }

    public Map<String, Object> getAssessment() {
        return assessment;
    }

    public void setAssessment(Map<String, Object> assessment) {
        this.assessment = (assessment == null) ? new HashMap<>() : assessment;
    }

    public Severity getOverallSeverity() {
        return overallSeverity;
    }

    public void setOverallSeverity(Severity overallSeverity) {
        this.overallSeverity = overallSeverity;
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

Create `backend/src/main/java/com/heartcare/symptoms/SymptomsRepository.java`:

```java
package com.heartcare.symptoms;

import com.heartcare.symptoms.model.SymptomLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SymptomsRepository extends JpaRepository<SymptomLog, UUID> {

    Optional<SymptomLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT s FROM SymptomLog s
            WHERE s.userId = :userId
              AND s.measuredAt >= :from
              AND s.measuredAt < :to
            ORDER BY s.measuredAt DESC
            """)
    List<SymptomLog> findHistory(@Param("userId") UUID userId,
                                 @Param("from") OffsetDateTime from,
                                 @Param("to") OffsetDateTime to);
}
```

- [ ] **Step 5: Write the failing round-trip test**

Create `backend/src/test/java/com/heartcare/symptoms/SymptomsRepositoryTest.java` (mirrors `VitalsRepositoryTest`; seeds a user with `JdbcTemplate` because of the FK):

```java
package com.heartcare.symptoms;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.symptoms.model.Severity;
import com.heartcare.symptoms.model.SymptomLog;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class SymptomsRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    SymptomsRepository symptomsRepository;

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
    void savesAndReloadsCheckInWithNestedJsonb() {
        UUID userId = seedUser();
        SymptomLog log = new SymptomLog();
        log.setUserId(userId);
        log.setData(Map.of(
                "chestPain", Map.of("present", true, "severity", 8),
                "shortnessOfBreath", "MILD",
                "heartRate", 82,
                "bloodPressure", Map.of("systolic", 165, "diastolic", 92),
                "swelling", true,
                "energyLevel", 4));
        log.setAssessment(Map.of(
                "overall", "EMERGENCY",
                "symptoms", Map.of("chestPain", "EMERGENCY", "heartRate", "NONE")));
        log.setOverallSeverity(Severity.EMERGENCY);
        log.setMeasuredAt(OffsetDateTime.now());

        SymptomLog saved = symptomsRepository.saveAndFlush(log);

        SymptomLog reloaded = symptomsRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getOverallSeverity()).isEqualTo(Severity.EMERGENCY);
        assertThat(reloaded.getData().get("shortnessOfBreath")).isEqualTo("MILD");
        assertThat(reloaded.getData().get("heartRate")).isEqualTo(82);
        @SuppressWarnings("unchecked")
        Map<String, Object> chestPain = (Map<String, Object>) reloaded.getData().get("chestPain");
        assertThat(chestPain.get("present")).isEqualTo(true);
        assertThat(chestPain.get("severity")).isEqualTo(8);
        @SuppressWarnings("unchecked")
        Map<String, Object> assessment = (Map<String, Object>) reloaded.getAssessment().get("symptoms");
        assertThat(assessment.get("chestPain")).isEqualTo("EMERGENCY");
    }

    @Test
    void findByUserIdAndClientRecordIdReturnsMatch() {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        SymptomLog log = new SymptomLog();
        log.setUserId(userId);
        log.setData(Map.of("swelling", false));
        log.setAssessment(Map.of("overall", "NONE"));
        log.setOverallSeverity(Severity.NONE);
        log.setMeasuredAt(OffsetDateTime.now());
        log.setClientRecordId(crid);
        symptomsRepository.saveAndFlush(log);

        assertThat(symptomsRepository.findByUserIdAndClientRecordId(userId, crid)).isPresent();
        assertThat(symptomsRepository.findByUserIdAndClientRecordId(userId, UUID.randomUUID())).isEmpty();
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd backend && mvn test -Dtest=SymptomsRepositoryTest`
Expected: PASS (2 tests). This confirms the `V6` migration applies on top of `V5`, the entity matches the schema under `ddl-auto=validate`, and nested JSONB round-trips (integers reload as `Integer`, so `isEqualTo(82)`/`isEqualTo(8)` hold).

If the context fails to start with a Hibernate `SchemaManagementException`, the entity and migration disagree — compare column names/types against `V6`. If nested numbers reload as a different type than expected, adjust the assertion to the actual reloaded type (do not change the entity map type).

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/resources/db/migration/V6__create_symptom_logs.sql \
        backend/src/main/java/com/heartcare/symptoms/model/Severity.java \
        backend/src/main/java/com/heartcare/symptoms/model/SymptomLog.java \
        backend/src/main/java/com/heartcare/symptoms/SymptomsRepository.java \
        backend/src/test/java/com/heartcare/symptoms/SymptomsRepositoryTest.java
git commit -m "feat(backend): add symptom_logs table, entity, repository (Slice 5)"
```

---

### Task 2: `SymptomAssessment` (clinical rules) + unit test

Pure, Spring-free severity classification. This is the clinical core (FR-SYM-010).

**Files:**
- Create: `backend/src/main/java/com/heartcare/symptoms/SymptomAssessment.java`
- Test: `backend/src/test/java/com/heartcare/symptoms/SymptomAssessmentTest.java`

**Interfaces:**
- Consumes: `Severity` (Task 1).
- Produces:
  - `class SymptomAssessment` (`@Component`).
  - nested `record SymptomAssessment.Assessment(Severity overall, Map<String,Severity> symptoms)`.
  - `Assessment assess(Map<String,Object> data)` — assumes `data` already structurally valid (Task 3 validates before calling); classifies each of the six symptoms and computes `overall` = max. `symptoms` map keys: `chestPain`, `shortnessOfBreath`, `bloodPressure`, `heartRate`, `swelling`, `energyLevel`.

- [ ] **Step 1: Write the failing test**

Create `backend/src/test/java/com/heartcare/symptoms/SymptomAssessmentTest.java`:

```java
package com.heartcare.symptoms;

import com.heartcare.symptoms.SymptomAssessment.Assessment;
import com.heartcare.symptoms.model.Severity;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class SymptomAssessmentTest {

    private final SymptomAssessment assessment = new SymptomAssessment();

    /** A fully benign check-in; individual tests override single fields. */
    private static Map<String, Object> benign() {
        Map<String, Object> data = new HashMap<>();
        data.put("chestPain", Map.of("present", false));
        data.put("shortnessOfBreath", "NONE");
        data.put("heartRate", 70);
        data.put("bloodPressure", Map.of("systolic", 120, "diastolic", 80));
        data.put("swelling", false);
        data.put("energyLevel", 8);
        return data;
    }

    @Test
    void allBenignIsNone() {
        Assessment result = assessment.assess(benign());
        assertThat(result.overall()).isEqualTo(Severity.NONE);
        assertThat(result.symptoms()).containsAllEntriesOf(Map.of(
                "chestPain", Severity.NONE,
                "shortnessOfBreath", Severity.NONE,
                "bloodPressure", Severity.NONE,
                "heartRate", Severity.NONE,
                "swelling", Severity.NONE,
                "energyLevel", Severity.NONE));
    }

    @Test
    void chestPainSeverityBoundaries() {
        assertThat(chestPain(0)).isEqualTo(Severity.NONE);
        assertThat(chestPain(1)).isEqualTo(Severity.MONITOR);
        assertThat(chestPain(3)).isEqualTo(Severity.MONITOR);
        assertThat(chestPain(4)).isEqualTo(Severity.URGENT);
        assertThat(chestPain(6)).isEqualTo(Severity.URGENT);
        assertThat(chestPain(7)).isEqualTo(Severity.EMERGENCY);
        assertThat(chestPain(10)).isEqualTo(Severity.EMERGENCY);
    }

    @Test
    void chestPainNotPresentIsNone() {
        Map<String, Object> data = benign();
        data.put("chestPain", Map.of("present", false));
        assertThat(assessment.assess(data).symptoms().get("chestPain")).isEqualTo(Severity.NONE);
    }

    @Test
    void shortnessOfBreathLevels() {
        assertThat(sob("NONE")).isEqualTo(Severity.NONE);
        assertThat(sob("MILD")).isEqualTo(Severity.MONITOR);
        assertThat(sob("SEVERE")).isEqualTo(Severity.URGENT);
    }

    @Test
    void bloodPressureLevels() {
        assertThat(bp(120, 80)).isEqualTo(Severity.NONE);
        assertThat(bp(160, 80)).isEqualTo(Severity.URGENT);   // systolic >= 160
        assertThat(bp(90, 80)).isEqualTo(Severity.URGENT);    // systolic <= 90
        assertThat(bp(140, 100)).isEqualTo(Severity.URGENT);  // diastolic >= 100
        assertThat(bp(140, 60)).isEqualTo(Severity.URGENT);   // diastolic <= 60
        assertThat(bp(180, 80)).isEqualTo(Severity.EMERGENCY); // systolic >= 180
    }

    @Test
    void heartRateLevels() {
        assertThat(hr(70)).isEqualTo(Severity.NONE);
        assertThat(hr(40)).isEqualTo(Severity.NONE);   // 40 is not < 40
        assertThat(hr(39)).isEqualTo(Severity.URGENT);
        assertThat(hr(120)).isEqualTo(Severity.NONE);  // 120 is not > 120
        assertThat(hr(121)).isEqualTo(Severity.URGENT);
    }

    @Test
    void swellingAndEnergyAreMonitorLevel() {
        Map<String, Object> swollen = benign();
        swollen.put("swelling", true);
        assertThat(assessment.assess(swollen).symptoms().get("swelling")).isEqualTo(Severity.MONITOR);

        assertThat(energy(2)).isEqualTo(Severity.MONITOR);
        assertThat(energy(3)).isEqualTo(Severity.NONE);
    }

    @Test
    void overallIsMaxAcrossSymptoms() {
        Map<String, Object> data = benign();
        data.put("swelling", true);                              // MONITOR
        data.put("chestPain", Map.of("present", true, "severity", 8)); // EMERGENCY
        Assessment result = assessment.assess(data);
        assertThat(result.overall()).isEqualTo(Severity.EMERGENCY);
    }

    // --- helpers: mutate one field of a benign check-in and read its classification ---

    private Severity chestPain(int severity) {
        Map<String, Object> data = benign();
        data.put("chestPain", Map.of("present", true, "severity", severity));
        return assessment.assess(data).symptoms().get("chestPain");
    }

    private Severity sob(String level) {
        Map<String, Object> data = benign();
        data.put("shortnessOfBreath", level);
        return assessment.assess(data).symptoms().get("shortnessOfBreath");
    }

    private Severity bp(int systolic, int diastolic) {
        Map<String, Object> data = benign();
        data.put("bloodPressure", Map.of("systolic", systolic, "diastolic", diastolic));
        return assessment.assess(data).symptoms().get("bloodPressure");
    }

    private Severity hr(int rate) {
        Map<String, Object> data = benign();
        data.put("heartRate", rate);
        return assessment.assess(data).symptoms().get("heartRate");
    }

    private Severity energy(int level) {
        Map<String, Object> data = benign();
        data.put("energyLevel", level);
        return assessment.assess(data).symptoms().get("energyLevel");
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend && mvn test -Dtest=SymptomAssessmentTest`
Expected: FAIL/compile error — `SymptomAssessment` does not exist yet.

- [ ] **Step 3: Write `SymptomAssessment`**

Create `backend/src/main/java/com/heartcare/symptoms/SymptomAssessment.java`:

```java
package com.heartcare.symptoms;

import com.heartcare.symptoms.model.Severity;
import org.springframework.stereotype.Component;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Centralized clinical severity rules for the daily symptom check-in (FR-SYM-010).
 * Each private classifier is the single seam for tuning a symptom's bounds; the class
 * can later be promoted to {@code @ConfigurationProperties} without touching callers.
 *
 * <p>Assumes {@code data} has already been structurally validated by
 * {@code SymptomsService} (required keys present, correct types, ranges enforced).
 * The §4.3 bounds are documented defaults pending clinical sign-off.
 */
@Component
public class SymptomAssessment {

    /** Per-symptom severities plus the overall (max) level. */
    public record Assessment(Severity overall, Map<String, Severity> symptoms) {
    }

    public Assessment assess(Map<String, Object> data) {
        Map<String, Severity> symptoms = new LinkedHashMap<>();
        symptoms.put("chestPain", chestPain(asMap(data.get("chestPain"))));
        symptoms.put("shortnessOfBreath", shortnessOfBreath((String) data.get("shortnessOfBreath")));
        symptoms.put("bloodPressure", bloodPressure(asMap(data.get("bloodPressure"))));
        symptoms.put("heartRate", heartRate(asInt(data.get("heartRate"))));
        symptoms.put("swelling", swelling((Boolean) data.get("swelling")));
        symptoms.put("energyLevel", energyLevel(asInt(data.get("energyLevel"))));

        Severity overall = symptoms.values().stream()
                .max(Comparator.naturalOrder())
                .orElse(Severity.NONE);
        return new Assessment(overall, symptoms);
    }

    private Severity chestPain(Map<String, Object> chestPain) {
        if (!Boolean.TRUE.equals(chestPain.get("present"))) {
            return Severity.NONE;
        }
        int severity = asInt(chestPain.get("severity"));
        if (severity >= 7) {
            return Severity.EMERGENCY;
        }
        if (severity >= 4) {
            return Severity.URGENT;
        }
        if (severity >= 1) {
            return Severity.MONITOR;
        }
        return Severity.NONE;
    }

    private Severity shortnessOfBreath(String level) {
        return switch (level) {
            case "SEVERE" -> Severity.URGENT;
            case "MILD" -> Severity.MONITOR;
            default -> Severity.NONE; // "NONE"
        };
    }

    private Severity bloodPressure(Map<String, Object> bp) {
        int systolic = asInt(bp.get("systolic"));
        int diastolic = asInt(bp.get("diastolic"));
        if (systolic >= 180) {
            return Severity.EMERGENCY;
        }
        if (systolic >= 160 || systolic <= 90 || diastolic >= 100 || diastolic <= 60) {
            return Severity.URGENT;
        }
        return Severity.NONE;
    }

    private Severity heartRate(int heartRate) {
        return (heartRate < 40 || heartRate > 120) ? Severity.URGENT : Severity.NONE;
    }

    private Severity swelling(Boolean swelling) {
        return Boolean.TRUE.equals(swelling) ? Severity.MONITOR : Severity.NONE;
    }

    private Severity energyLevel(int energyLevel) {
        return energyLevel <= 2 ? Severity.MONITOR : Severity.NONE;
    }

    private static int asInt(Object value) {
        return ((Number) value).intValue();
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asMap(Object value) {
        return (Map<String, Object>) value;
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd backend && mvn test -Dtest=SymptomAssessmentTest`
Expected: PASS (all tests). If a boundary assertion fails, the bug is in a `>=`/`<=`/`>`/`<` — match the §4.3 table exactly (e.g. HR uses strict `< 40`/`> 120`, so 40 and 120 are `NONE`).

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/heartcare/symptoms/SymptomAssessment.java \
        backend/src/test/java/com/heartcare/symptoms/SymptomAssessmentTest.java
git commit -m "feat(backend): add SymptomAssessment severity rules with unit tests (Slice 5)"
```

---

### Task 3: DTOs + `SymptomsService` (validation, assessment, idempotency, date bounds) + unit test

The service orchestrates: idempotency, structural validation, server-computed assessment, UTC date-bounds conversion.

**Files:**
- Create: `backend/src/main/java/com/heartcare/symptoms/dto/SymptomLogRequest.java`
- Create: `backend/src/main/java/com/heartcare/symptoms/dto/SymptomLogResponse.java`
- Create: `backend/src/main/java/com/heartcare/symptoms/SymptomsService.java`
- Test: `backend/src/test/java/com/heartcare/symptoms/SymptomsServiceTest.java`

**Interfaces:**
- Consumes: `SymptomsRepository` (Task 1), `SymptomAssessment` + `Assessment` (Task 2), `Severity`, `SymptomLog`, `BadRequestException`.
- Produces:
  - `record SymptomLogRequest(Map<String,Object> data, OffsetDateTime measuredAt, String note, UUID clientRecordId)`.
  - `record SymptomLogResponse(String id, Map<String,Object> data, Map<String,Object> assessment, OffsetDateTime measuredAt, String note, String clientRecordId, OffsetDateTime createdAt)`.
  - `class SymptomsService` (`@Service`) with `SymptomLogResponse log(UUID userId, SymptomLogRequest request)` and `List<SymptomLogResponse> history(UUID userId, LocalDate from, LocalDate to)`.

- [ ] **Step 1: Write the DTOs**

Create `backend/src/main/java/com/heartcare/symptoms/dto/SymptomLogRequest.java`:

```java
package com.heartcare.symptoms.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

public record SymptomLogRequest(
        @NotNull(message = "data is required")
        Map<String, Object> data,

        OffsetDateTime measuredAt,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        UUID clientRecordId) {
}
```

Create `backend/src/main/java/com/heartcare/symptoms/dto/SymptomLogResponse.java`:

```java
package com.heartcare.symptoms.dto;

import java.time.OffsetDateTime;
import java.util.Map;

public record SymptomLogResponse(
        String id,
        Map<String, Object> data,
        Map<String, Object> assessment,
        OffsetDateTime measuredAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
```

- [ ] **Step 2: Write the failing service test**

Create `backend/src/test/java/com/heartcare/symptoms/SymptomsServiceTest.java`:

```java
package com.heartcare.symptoms;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.symptoms.dto.SymptomLogRequest;
import com.heartcare.symptoms.dto.SymptomLogResponse;
import com.heartcare.symptoms.model.SymptomLog;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
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
class SymptomsServiceTest {

    @Mock
    SymptomsRepository symptomsRepository;

    SymptomsService service;

    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new SymptomsService(symptomsRepository, new SymptomAssessment());
    }

    private static Map<String, Object> benignData() {
        Map<String, Object> data = new HashMap<>();
        data.put("chestPain", Map.of("present", false));
        data.put("shortnessOfBreath", "NONE");
        data.put("heartRate", 70);
        data.put("bloodPressure", Map.of("systolic", 120, "diastolic", 80));
        data.put("swelling", false);
        data.put("energyLevel", 8);
        return data;
    }

    private SymptomLogRequest request(Map<String, Object> data, UUID crid) {
        return new SymptomLogRequest(data, null, null, crid);
    }

    @Test
    void logComputesAssessmentAndOverall() {
        when(symptomsRepository.save(any(SymptomLog.class))).thenAnswer(inv -> inv.getArgument(0));
        Map<String, Object> data = benignData();
        data.put("chestPain", Map.of("present", true, "severity", 9));

        SymptomLogResponse response = service.log(userId, request(data, null));

        @SuppressWarnings("unchecked")
        Map<String, Object> symptoms = (Map<String, Object>) response.assessment().get("symptoms");
        assertThat(response.assessment().get("overall")).isEqualTo("EMERGENCY");
        assertThat(symptoms.get("chestPain")).isEqualTo("EMERGENCY");
    }

    @Test
    void logPersistsOverallSeverityColumn() {
        when(symptomsRepository.save(any(SymptomLog.class))).thenAnswer(inv -> {
            SymptomLog saved = inv.getArgument(0);
            assertThat(saved.getOverallSeverity().name()).isEqualTo("NONE");
            return saved;
        });
        service.log(userId, request(benignData(), null));
        verify(symptomsRepository).save(any(SymptomLog.class));
    }

    @Test
    void logDefaultsMeasuredAtWhenNull() {
        when(symptomsRepository.save(any(SymptomLog.class))).thenAnswer(inv -> inv.getArgument(0));
        SymptomLogResponse response = service.log(userId, request(benignData(), null));
        assertThat(response.measuredAt()).isNotNull();
    }

    @Test
    void logIsIdempotentOnClientRecordId() {
        UUID crid = UUID.randomUUID();
        SymptomLog existing = new SymptomLog();
        existing.setUserId(userId);
        existing.setData(Map.of("swelling", true));
        existing.setAssessment(Map.of("overall", "MONITOR"));
        existing.setOverallSeverity(com.heartcare.symptoms.model.Severity.MONITOR);
        existing.setMeasuredAt(OffsetDateTime.now());
        when(symptomsRepository.findByUserIdAndClientRecordId(userId, crid)).thenReturn(Optional.of(existing));

        SymptomLogResponse response = service.log(userId, request(benignData(), crid));

        assertThat(response.assessment().get("overall")).isEqualTo("MONITOR");
        verify(symptomsRepository, never()).save(any());
    }

    @Test
    void logIgnoresClientSentAssessment() {
        when(symptomsRepository.save(any(SymptomLog.class))).thenAnswer(inv -> inv.getArgument(0));
        Map<String, Object> data = benignData();
        data.put("assessment", Map.of("overall", "EMERGENCY")); // stray key -> rejected as unknown

        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsMissingRequiredKey() {
        Map<String, Object> data = benignData();
        data.remove("heartRate");
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsUnknownKey() {
        Map<String, Object> data = benignData();
        data.put("mood", "happy");
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsBadShortnessOfBreathEnum() {
        Map<String, Object> data = benignData();
        data.put("shortnessOfBreath", "WHEEZY");
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsOutOfRangeHeartRate() {
        Map<String, Object> data = benignData();
        data.put("heartRate", 900);
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsSystolicNotGreaterThanDiastolic() {
        Map<String, Object> data = benignData();
        data.put("bloodPressure", Map.of("systolic", 80, "diastolic", 80));
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsChestPainPresentWithoutSeverity() {
        Map<String, Object> data = benignData();
        data.put("chestPain", Map.of("present", true)); // no severity
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void historyDelegatesWithUtcDayBounds() {
        LocalDate from = LocalDate.of(2026, 7, 1);
        LocalDate to = LocalDate.of(2026, 7, 31);
        OffsetDateTime fromTs = OffsetDateTime.of(2026, 7, 1, 0, 0, 0, 0, ZoneOffset.UTC);
        OffsetDateTime toTs = OffsetDateTime.of(2026, 8, 1, 0, 0, 0, 0, ZoneOffset.UTC);
        when(symptomsRepository.findHistory(userId, fromTs, toTs)).thenReturn(List.of());

        service.history(userId, from, to);

        verify(symptomsRepository).findHistory(userId, fromTs, toTs);
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd backend && mvn test -Dtest=SymptomsServiceTest`
Expected: FAIL/compile error — `SymptomsService` does not exist yet.

- [ ] **Step 4: Write `SymptomsService`**

Create `backend/src/main/java/com/heartcare/symptoms/SymptomsService.java`:

```java
package com.heartcare.symptoms;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.symptoms.SymptomAssessment.Assessment;
import com.heartcare.symptoms.dto.SymptomLogRequest;
import com.heartcare.symptoms.dto.SymptomLogResponse;
import com.heartcare.symptoms.model.Severity;
import com.heartcare.symptoms.model.SymptomLog;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class SymptomsService {

    // Required check-in keys (worseThanYesterday is optional; assessment is server-owned).
    private static final Set<String> REQUIRED_KEYS = Set.of(
            "chestPain", "shortnessOfBreath", "heartRate", "bloodPressure", "swelling", "energyLevel");
    private static final Set<String> OPTIONAL_KEYS = Set.of("worseThanYesterday");
    private static final Set<String> SOB_LEVELS = Set.of("NONE", "MILD", "SEVERE");
    private static final Set<String> KNOWN_SYMPTOM_NAMES = Set.of(
            "chestPain", "shortnessOfBreath", "heartRate", "bloodPressure", "swelling", "energyLevel");

    // Sentinel bounds for open-ended date filters (safe within Postgres timestamptz range).
    private static final OffsetDateTime MIN_INSTANT = OffsetDateTime.of(1, 1, 1, 0, 0, 0, 0, ZoneOffset.UTC);
    private static final OffsetDateTime MAX_INSTANT = OffsetDateTime.of(9999, 12, 31, 0, 0, 0, 0, ZoneOffset.UTC);

    private final SymptomsRepository symptomsRepository;
    private final SymptomAssessment assessment;

    public SymptomsService(SymptomsRepository symptomsRepository, SymptomAssessment assessment) {
        this.symptomsRepository = symptomsRepository;
        this.assessment = assessment;
    }

    @Transactional
    public SymptomLogResponse log(UUID userId, SymptomLogRequest request) {
        if (request.clientRecordId() != null) {
            var existing = symptomsRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        Map<String, Object> data = validate(request.data());
        Assessment result = assessment.assess(data);

        SymptomLog log = new SymptomLog();
        log.setUserId(userId);
        log.setData(data);
        log.setAssessment(toAssessmentMap(result));
        log.setOverallSeverity(result.overall());
        log.setMeasuredAt(request.measuredAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.measuredAt());
        log.setNote(request.note());
        log.setClientRecordId(request.clientRecordId());
        return toResponse(symptomsRepository.save(log));
    }

    @Transactional(readOnly = true)
    public List<SymptomLogResponse> history(UUID userId, LocalDate from, LocalDate to) {
        // Bucket calendar-date filters by UTC day; the query range is half-open [fromTs, toTs).
        OffsetDateTime fromTs = from == null ? MIN_INSTANT : from.atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        OffsetDateTime toTs = to == null ? MAX_INSTANT : to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        return symptomsRepository.findHistory(userId, fromTs, toTs)
                .stream().map(this::toResponse).toList();
    }

    private Map<String, Object> validate(Map<String, Object> raw) {
        if (raw == null) {
            throw new BadRequestException("data is required");
        }
        for (String key : raw.keySet()) {
            if (!REQUIRED_KEYS.contains(key) && !OPTIONAL_KEYS.contains(key)) {
                throw new BadRequestException("unknown key in data: " + key);
            }
        }
        for (String key : REQUIRED_KEYS) {
            if (!raw.containsKey(key)) {
                throw new BadRequestException("data must contain " + key);
            }
        }

        validateChestPain(asMap(raw.get("chestPain"), "chestPain"));
        validateEnum(raw.get("shortnessOfBreath"), "shortnessOfBreath", SOB_LEVELS);
        intInRange(raw.get("heartRate"), "heartRate", 20, 300);
        validateBloodPressure(asMap(raw.get("bloodPressure"), "bloodPressure"));
        boolValue(raw.get("swelling"), "swelling");
        intInRange(raw.get("energyLevel"), "energyLevel", 0, 10);
        if (raw.containsKey("worseThanYesterday")) {
            validateWorseThanYesterday(asMap(raw.get("worseThanYesterday"), "worseThanYesterday"));
        }
        return raw;
    }

    private void validateChestPain(Map<String, Object> chestPain) {
        boolean present = boolValue(chestPain.get("present"), "chestPain.present");
        if (present) {
            if (!chestPain.containsKey("severity")) {
                throw new BadRequestException("chestPain.severity is required when present");
            }
            intInRange(chestPain.get("severity"), "chestPain.severity", 0, 10);
        }
    }

    private void validateBloodPressure(Map<String, Object> bp) {
        int systolic = intInRange(bp.get("systolic"), "systolic", 40, 300);
        int diastolic = intInRange(bp.get("diastolic"), "diastolic", 40, 300);
        if (systolic <= diastolic) {
            throw new BadRequestException("systolic must be greater than diastolic");
        }
    }

    private void validateWorseThanYesterday(Map<String, Object> worse) {
        for (Map.Entry<String, Object> entry : worse.entrySet()) {
            if (!KNOWN_SYMPTOM_NAMES.contains(entry.getKey())) {
                throw new BadRequestException("unknown symptom in worseThanYesterday: " + entry.getKey());
            }
            boolValue(entry.getValue(), "worseThanYesterday." + entry.getKey());
        }
    }

    private void validateEnum(Object value, String field, Set<String> allowed) {
        if (!(value instanceof String s) || !allowed.contains(s)) {
            throw new BadRequestException(field + " must be one of " + allowed);
        }
    }

    private int intInRange(Object value, String field, int min, int max) {
        if (!(value instanceof Number number)) {
            throw new BadRequestException(field + " must be a number");
        }
        double d = number.doubleValue();
        if (d != Math.rint(d)) {
            throw new BadRequestException(field + " must be a whole number");
        }
        int i = number.intValue();
        if (i < min || i > max) {
            throw new BadRequestException(field + " is out of range");
        }
        return i;
    }

    private boolean boolValue(Object value, String field) {
        if (!(value instanceof Boolean b)) {
            throw new BadRequestException(field + " must be true or false");
        }
        return b;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> asMap(Object value, String field) {
        if (!(value instanceof Map)) {
            throw new BadRequestException(field + " must be an object");
        }
        return (Map<String, Object>) value;
    }

    private Map<String, Object> toAssessmentMap(Assessment result) {
        Map<String, Object> symptoms = new LinkedHashMap<>();
        result.symptoms().forEach((k, v) -> symptoms.put(k, v.name()));
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("overall", result.overall().name());
        map.put("symptoms", symptoms);
        return map;
    }

    private SymptomLogResponse toResponse(SymptomLog log) {
        return new SymptomLogResponse(
                log.getId() == null ? null : log.getId().toString(),
                log.getData(),
                log.getAssessment(),
                log.getMeasuredAt(),
                log.getNote(),
                log.getClientRecordId() == null ? null : log.getClientRecordId().toString(),
                log.getCreatedAt());
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd backend && mvn test -Dtest=SymptomsServiceTest`
Expected: PASS (all tests). Note: `logIgnoresClientSentAssessment` asserts that a stray `assessment` key in `data` is rejected as an unknown key (the server never reads a client assessment; `data` accepts only the documented keys).

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/heartcare/symptoms/dto/SymptomLogRequest.java \
        backend/src/main/java/com/heartcare/symptoms/dto/SymptomLogResponse.java \
        backend/src/main/java/com/heartcare/symptoms/SymptomsService.java \
        backend/src/test/java/com/heartcare/symptoms/SymptomsServiceTest.java
git commit -m "feat(backend): add SymptomsService with validation/assessment and unit tests (Slice 5)"
```

---

### Task 4: `SymptomsController` + integration test + full suite

Wires the HTTP layer and proves the whole feature end-to-end on real Postgres.

**Files:**
- Create: `backend/src/main/java/com/heartcare/symptoms/SymptomsController.java`
- Test: `backend/src/test/java/com/heartcare/symptoms/SymptomsControllerIntegrationTest.java`

**Interfaces:**
- Consumes: `SymptomsService` (Task 3), `ApiResponse`, `UserPrincipal`, `SymptomLogRequest`, `SymptomLogResponse`.
- Produces: `SymptomsController` exposing `POST /api/v1/symptoms` and `GET /api/v1/symptoms?from=&to=`.

- [ ] **Step 1: Write the controller**

Create `backend/src/main/java/com/heartcare/symptoms/SymptomsController.java` (mirrors `VitalsController`; no `type` param):

```java
package com.heartcare.symptoms;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.symptoms.dto.SymptomLogRequest;
import com.heartcare.symptoms.dto.SymptomLogResponse;
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
public class SymptomsController {

    private final SymptomsService symptomsService;

    public SymptomsController(SymptomsService symptomsService) {
        this.symptomsService = symptomsService;
    }

    @PostMapping("/symptoms")
    public ApiResponse<SymptomLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody SymptomLogRequest request) {
        return ApiResponse.ok(symptomsService.log(principal.userId(), request), "Symptom check-in logged");
    }

    @GetMapping("/symptoms")
    public ApiResponse<List<SymptomLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(symptomsService.history(principal.userId(), from, to));
    }
}
```

- [ ] **Step 2: Write the failing integration test**

Create `backend/src/test/java/com/heartcare/symptoms/SymptomsControllerIntegrationTest.java` (mirrors `VitalsControllerIntegrationTest`):

```java
package com.heartcare.symptoms;

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

class SymptomsControllerIntegrationTest extends AbstractIntegrationTest {

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

    private void postCheckIn(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk());
    }

    private static final String BENIGN = """
            { "data": {
                "chestPain": { "present": false },
                "shortnessOfBreath": "NONE",
                "heartRate": 70,
                "bloodPressure": { "systolic": 120, "diastolic": 80 },
                "swelling": false,
                "energyLevel": 8
            } }""";

    @Test
    void unauthenticatedReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/symptoms")
                        .contentType(APPLICATION_JSON).content(BENIGN))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logThenHistoryReturnsCheckIn() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": true, "severity": 8 },
                                    "shortnessOfBreath": "MILD",
                                    "heartRate": 82,
                                    "bloodPressure": { "systolic": 165, "diastolic": 92 },
                                    "swelling": true,
                                    "energyLevel": 4
                                }, "note": "tight chest" }"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.assessment.overall").value("EMERGENCY"))
                .andExpect(jsonPath("$.data.assessment.symptoms.chestPain").value("EMERGENCY"))
                .andExpect(jsonPath("$.data.assessment.symptoms.bloodPressure").value("URGENT"))
                .andExpect(jsonPath("$.data.data.heartRate").value(82));

        mockMvc.perform(get("/api/v1/symptoms").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].assessment.overall").value("EMERGENCY"))
                .andExpect(jsonPath("$.data[0].note").value("tight chest"));
    }

    @Test
    void benignCheckInIsNone() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(BENIGN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.assessment.overall").value("NONE"));
    }

    @Test
    void historyFiltersByDateRangeInUtc() throws Exception {
        String token = registerAndGetToken();
        // 23:30Z on 2026-07-10 is still 2026-07-10 in UTC; 00:30Z on 2026-07-11 is 2026-07-11.
        postCheckIn(token, withMeasuredAt("2026-07-10T23:30:00Z"));
        postCheckIn(token, withMeasuredAt("2026-07-11T00:30:00Z"));

        mockMvc.perform(get("/api/v1/symptoms?from=2026-07-11&to=2026-07-11")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].measuredAt").value(org.hamcrest.Matchers.startsWith("2026-07-11")));
    }

    private static String withMeasuredAt(String iso) {
        return """
                { "data": {
                    "chestPain": { "present": false },
                    "shortnessOfBreath": "NONE",
                    "heartRate": 70,
                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                    "swelling": false,
                    "energyLevel": 8
                }, "measuredAt": "%s" }""".formatted(iso);
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String crid = UUID.randomUUID().toString();
        String body = """
                { "data": {
                    "chestPain": { "present": false },
                    "shortnessOfBreath": "NONE",
                    "heartRate": 70,
                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                    "swelling": false,
                    "energyLevel": 8
                }, "clientRecordId": "%s" }""".formatted(crid);
        postCheckIn(token, body);
        postCheckIn(token, body);

        mockMvc.perform(get("/api/v1/symptoms").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void missingRequiredKeyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": false },
                                    "shortnessOfBreath": "NONE",
                                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                                    "swelling": false,
                                    "energyLevel": 8
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void badShortnessOfBreathEnumReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": false },
                                    "shortnessOfBreath": "WHEEZY",
                                    "heartRate": 70,
                                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                                    "swelling": false,
                                    "energyLevel": 8
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void systolicNotGreaterThanDiastolicReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": false },
                                    "shortnessOfBreath": "NONE",
                                    "heartRate": 70,
                                    "bloodPressure": { "systolic": 80, "diastolic": 80 },
                                    "swelling": false,
                                    "energyLevel": 8
                                } }"""))
                .andExpect(status().isBadRequest());
    }
}
```

- [ ] **Step 3: Run the integration test to verify it passes**

Run: `cd backend && mvn test -Dtest=SymptomsControllerIntegrationTest`
Expected: PASS (all tests). Requires Docker (Testcontainers). This exercises the real `findHistory` query, nested JSONB persistence, the UTC-day filter, idempotency, and the 400 paths.

- [ ] **Step 4: Run the FULL suite to confirm no regressions**

Run: `cd backend && mvn test`
Expected: BUILD SUCCESS; the summary line shows all tests passing (Slice 4 left the suite at 106; this slice adds the new symptom tests on top). If anything unrelated breaks, stop and investigate before committing.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/heartcare/symptoms/SymptomsController.java \
        backend/src/test/java/com/heartcare/symptoms/SymptomsControllerIntegrationTest.java
git commit -m "feat(backend): add symptoms endpoints with integration tests (Slice 5)"
```

---

### Task 5: Documentation

Reflect Slice 5 in the backend docs. Docs-only; no test cycle, but verify against the implemented code.

**Files:**
- Modify: `backend/README.md` (build-progress table)
- Modify: `backend/docs/API.md` (add the two symptom endpoints)
- Modify: `backend/docs/DATABASE.md` (add `symptom_logs` + `V6` migration-log entry)

- [ ] **Step 1: Flip Slice 5 to done in `backend/README.md`**

In the Build Progress table, change the Slice 5 row from `⬜ Not started` to `✅ Done` and expand its description:

```markdown
| 5 | Symptoms (daily check-in: chest pain/SOB/HR/BP/swelling/energy, server-computed severity assessment, JSONB data) | ✅ Done |
```

- [ ] **Step 2: Add the symptom endpoints to `backend/docs/API.md`**

Follow the existing vitals section's structure. Document, for `POST /api/v1/symptoms` and `GET /api/v1/symptoms?from=&to=`: Bearer auth, the `ApiResponse<T>` envelope, the `data` keys and their types/ranges (from spec §4.1), the server-computed `assessment` shape (`overall` + per-symptom `Severity`), that any client-sent `assessment` is rejected, `measuredAt` defaults to now (UTC), `clientRecordId` idempotency, and UTC-day `from`/`to` filtering. Include the **`Severity` → recommended-action** client mapping table for FR-SYM-010, marked as client-rendered / bilingual:

```markdown
| Severity | Recommended action (rendered client-side, EN/AM) |
|----------|--------------------------------------------------|
| NONE | No action; keep monitoring |
| MONITOR | Self-care; watch for changes |
| URGENT | Contact your clinician today |
| EMERGENCY | Call your emergency contact now |
```

Note in the doc that these thresholds/actions are documented defaults pending clinical sign-off (spec §0).

- [ ] **Step 3: Add `symptom_logs` to `backend/docs/DATABASE.md`**

Following the `vitals_logs` entry's format, add the `symptom_logs` table (columns, types, nullability, indexes, the `uq_symptom_user_client_record` unique constraint) and a `V6__create_symptom_logs.sql` row in the migration log. Note `data` and `assessment` are JSONB and `overall_severity` is a queryable snapshot of `assessment.overall`.

- [ ] **Step 4: Sanity-check the docs against the code**

Re-read the three docs and confirm every documented key, type, endpoint, and column matches the implemented `SymptomsController`/`SymptomsService`/`SymptomLog`/`V6`. Fix any drift.

- [ ] **Step 5: Commit**

```bash
git add backend/README.md backend/docs/API.md backend/docs/DATABASE.md
git commit -m "docs(backend): document Slice 5 symptom endpoints and schema"
```

---

## Self-Review (completed during planning)

**Spec coverage:** every FR-SYM row maps to a task — capture/validation (Task 3), per-symptom + overall severity FR-SYM-010 (Task 2), history + date filter FR-SYM-009 (Tasks 1/3/4), idempotency/offline FR-SYM-011 (Tasks 1/3/4), `worseThanYesterday` FR-SYM-008 stored client-reported (Task 3 validation accepts it as optional). Spec decisions 1–7 all realized. §0 clinical-sign-off caveat surfaced in Task 2/Task 5 docs.

**Placeholder scan:** no TBD/TODO; every code step shows complete code; every run step shows the exact command and expected result.

**Type consistency:** `Severity` enum order fixed and relied on by `Comparator.naturalOrder()`; `SymptomAssessment.Assessment(overall, symptoms)` produced in Task 2 and consumed in Task 3; `assess(Map<String,Object>)`, `findHistory(UUID, OffsetDateTime, OffsetDateTime)`, `log(UUID, SymptomLogRequest)`, `history(UUID, LocalDate, LocalDate)` signatures match across tasks; DTO field names (`data`, `assessment`, `measuredAt`, `note`, `clientRecordId`, `id`, `createdAt`) consistent between service `toResponse`, DTO records, and integration-test JSON paths; `overall_severity` column ↔ `overallSeverity` entity field ↔ `VARCHAR(20)` all aligned.
