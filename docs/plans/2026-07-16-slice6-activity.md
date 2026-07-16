# Slice 6 — Activity Logging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a patient-scoped physical-activity log (`POST /activities`, `GET /activities`) — the fourth time-series-log feature — persisting one activity session per row and serving date-filtered history.

**Architecture:** Package-by-feature under `com.heartcare.activity`, mirroring the Slice 5 symptoms feature but **simpler**: there is no server-computed value (no `assessment`, no `overall_severity`), no clinical-rules class, and no cross-feature dependency. The service validates the JSONB `data` shape, applies `client_record_id` idempotency, converts calendar-date filters to a half-open UTC range, persists, and serves. Logs are append-only (no update/delete).

**Tech Stack:** Java 21 · Spring Boot 4.1.0 · Spring Data JPA · Hibernate `@JdbcTypeCode(SqlTypes.JSON)` on PostgreSQL 16 · Flyway · JUnit 5 + Mockito + Testcontainers + AssertJ + JsonPath.

## Global Constraints

- **Package base:** `com.heartcare` — new feature package `com.heartcare.activity` (sub-packages `.model`, `.dto`).
- **Endpoints:** base path `/api/v1`; every endpoint requires a Bearer JWT and is scoped to `principal.userId()` (`UserPrincipal`). No security-config change is needed — everything outside `/api/v1/auth/**` is authenticated by default (same as vitals/symptoms).
- **Response envelope:** all responses use `com.heartcare.common.response.ApiResponse<T>` (`ApiResponse.ok(body)` / `ApiResponse.ok(body, message)`).
- **Validation errors:** throw `com.heartcare.common.exception.BadRequestException` (mapped to HTTP 400 by the existing `GlobalExceptionHandler`).
- **Idempotency:** `UNIQUE (user_id, client_record_id)`; a `POST` whose `clientRecordId` already exists for the user returns the existing row unchanged (no new insert).
- **Dates:** history `from`/`to` are ISO calendar dates bucketed by **UTC day** via a half-open range `[from 00:00Z, day-after-to 00:00Z)`. Null `from` → `MIN_INSTANT`; null `to` → `MAX_INSTANT`.
- **Append-only:** no update or delete endpoints; a correction is a new row.
- **Hibernate DDL:** runs under `ddl-auto=validate` — the entity mapping MUST match the `V7` migration columns exactly.
- **Migration numbering:** next free version is `V7`; place SQL in `backend/src/main/resources/db/migration/`.
- **Commits:** Conventional-commit style, e.g. `feat(backend): ...`. **Do NOT add a Claude/AI co-author trailer** — the repository owner is the sole commit author.
- **Working directory for all commands:** `backend/`.

---

## File Structure

- `backend/src/main/resources/db/migration/V7__create_activity_logs.sql` — new table.
- `backend/src/main/java/com/heartcare/activity/model/ActivityType.java` — enum, allowed activity types.
- `backend/src/main/java/com/heartcare/activity/model/Intensity.java` — enum, allowed intensities.
- `backend/src/main/java/com/heartcare/activity/model/ActivityLog.java` — `@Entity`, JSONB `data`.
- `backend/src/main/java/com/heartcare/activity/ActivityRepository.java` — idempotency finder + history query.
- `backend/src/main/java/com/heartcare/activity/dto/ActivityLogRequest.java` — request record.
- `backend/src/main/java/com/heartcare/activity/dto/ActivityLogResponse.java` — response record.
- `backend/src/main/java/com/heartcare/activity/ActivityService.java` — validation, idempotency, date bounds, mapping.
- `backend/src/main/java/com/heartcare/activity/ActivityController.java` — the two endpoints.
- `backend/src/test/java/com/heartcare/activity/ActivityRepositoryTest.java` — JSONB round-trip + finder (Task 1).
- `backend/src/test/java/com/heartcare/activity/ActivityServiceTest.java` — unit, mocked repo (Task 2).
- `backend/src/test/java/com/heartcare/activity/ActivityControllerIntegrationTest.java` — black-box (Task 3).
- `backend/README.md`, `backend/docs/API.md`, `backend/docs/DATABASE.md` — docs (Task 4).

---

## Task 1: Persistence layer (migration, enums, entity, repository)

**Files:**
- Create: `backend/src/main/resources/db/migration/V7__create_activity_logs.sql`
- Create: `backend/src/main/java/com/heartcare/activity/model/ActivityType.java`
- Create: `backend/src/main/java/com/heartcare/activity/model/Intensity.java`
- Create: `backend/src/main/java/com/heartcare/activity/model/ActivityLog.java`
- Create: `backend/src/main/java/com/heartcare/activity/ActivityRepository.java`
- Test: `backend/src/test/java/com/heartcare/activity/ActivityRepositoryTest.java`

**Interfaces:**
- Consumes: `com.heartcare.AbstractIntegrationTest` (Testcontainers Postgres base); existing `users` table.
- Produces:
  - `ActivityLog` entity with getters/setters for `id (UUID)`, `userId (UUID)`, `data (Map<String,Object>)`, `measuredAt (OffsetDateTime)`, `note (String)`, `clientRecordId (UUID)`, `createdAt (OffsetDateTime)`; no-arg constructor; `@PrePersist` defaulting `createdAt`.
  - `ActivityType` enum: `WALKING, JOGGING, CYCLING, HOUSEHOLD, FARMING, STRETCHING, OTHER`.
  - `Intensity` enum: `LIGHT, MODERATE, VIGOROUS`.
  - `ActivityRepository extends JpaRepository<ActivityLog, UUID>` with `Optional<ActivityLog> findByUserIdAndClientRecordId(UUID, UUID)` and `List<ActivityLog> findHistory(UUID userId, OffsetDateTime from, OffsetDateTime to)`.

- [ ] **Step 1: Write the failing repository test**

Create `backend/src/test/java/com/heartcare/activity/ActivityRepositoryTest.java`:

```java
package com.heartcare.activity;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.activity.model.ActivityLog;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class ActivityRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    ActivityRepository activityRepository;

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
    void savesAndReloadsActivityWithJsonb() {
        UUID userId = seedUser();
        ActivityLog log = new ActivityLog();
        log.setUserId(userId);
        log.setData(Map.of(
                "type", "WALKING",
                "durationMinutes", 30,
                "intensity", "MODERATE",
                "steps", 3200,
                "distanceMeters", 2400));
        log.setMeasuredAt(OffsetDateTime.now());
        log.setNote("morning walk");

        ActivityLog saved = activityRepository.saveAndFlush(log);

        ActivityLog reloaded = activityRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getData().get("type")).isEqualTo("WALKING");
        assertThat(reloaded.getData().get("durationMinutes")).isEqualTo(30);
        assertThat(reloaded.getData().get("intensity")).isEqualTo("MODERATE");
        assertThat(reloaded.getData().get("steps")).isEqualTo(3200);
        assertThat(reloaded.getNote()).isEqualTo("morning walk");
    }

    @Test
    void findByUserIdAndClientRecordIdReturnsMatch() {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        ActivityLog log = new ActivityLog();
        log.setUserId(userId);
        log.setData(Map.of("type", "WALKING", "durationMinutes", 20, "intensity", "LIGHT"));
        log.setMeasuredAt(OffsetDateTime.now());
        log.setClientRecordId(crid);
        activityRepository.saveAndFlush(log);

        assertThat(activityRepository.findByUserIdAndClientRecordId(userId, crid)).isPresent();
        assertThat(activityRepository.findByUserIdAndClientRecordId(userId, UUID.randomUUID())).isEmpty();
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mvn test -Dtest=ActivityRepositoryTest`
Expected: FAIL — compilation error (`ActivityLog` / `ActivityRepository` do not exist yet).

- [ ] **Step 3: Create the migration**

Create `backend/src/main/resources/db/migration/V7__create_activity_logs.sql`:

```sql
-- One row per logged physical-activity session. `data` holds the patient's entered
-- fields (type, durationMinutes, intensity, optional steps/distanceMeters). Unlike
-- vitals/symptoms this slice computes nothing, so there is no assessment/severity column.
CREATE TABLE activity_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    data              JSONB NOT NULL,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_activity_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_activity_user_measured ON activity_logs(user_id, measured_at);
```

- [ ] **Step 4: Create the two enums**

Create `backend/src/main/java/com/heartcare/activity/model/ActivityType.java`:

```java
package com.heartcare.activity.model;

/**
 * Curated set of loggable activity types (FR-ACT-003). Stored as its string value inside
 * the activity_logs.data JSONB; the client maps each constant to a localized EN/AM label.
 * OTHER plus the free-text note covers the long tail. Extending this list needs no migration.
 */
public enum ActivityType {
    WALKING,
    JOGGING,
    CYCLING,
    HOUSEHOLD,
    FARMING,
    STRETCHING,
    OTHER
}
```

Create `backend/src/main/java/com/heartcare/activity/model/Intensity.java`:

```java
package com.heartcare.activity.model;

/**
 * Physical-activity intensity (FR-ACT-003), the standard CHD exercise-guidance scale.
 * Stored as its string value inside the activity_logs.data JSONB.
 */
public enum Intensity {
    LIGHT,
    MODERATE,
    VIGOROUS
}
```

- [ ] **Step 5: Create the entity**

Create `backend/src/main/java/com/heartcare/activity/model/ActivityLog.java`:

```java
package com.heartcare.activity.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "activity_logs")
public class ActivityLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "data", nullable = false)
    private Map<String, Object> data = new HashMap<>();

    @Column(name = "measured_at", nullable = false)
    private OffsetDateTime measuredAt;

    @Column(name = "note")
    private String note;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public ActivityLog() {
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

- [ ] **Step 6: Create the repository**

Create `backend/src/main/java/com/heartcare/activity/ActivityRepository.java`:

```java
package com.heartcare.activity;

import com.heartcare.activity.model.ActivityLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ActivityRepository extends JpaRepository<ActivityLog, UUID> {

    Optional<ActivityLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT a FROM ActivityLog a
            WHERE a.userId = :userId
              AND a.measuredAt >= :from
              AND a.measuredAt < :to
            ORDER BY a.measuredAt DESC
            """)
    List<ActivityLog> findHistory(@Param("userId") UUID userId,
                                  @Param("from") OffsetDateTime from,
                                  @Param("to") OffsetDateTime to);
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `mvn test -Dtest=ActivityRepositoryTest`
Expected: PASS (2 tests). Flyway applies `V7`; JSONB `data` round-trips; the finder matches on `clientRecordId`.

- [ ] **Step 8: Commit**

```bash
git add backend/src/main/resources/db/migration/V7__create_activity_logs.sql \
        backend/src/main/java/com/heartcare/activity/model/ActivityType.java \
        backend/src/main/java/com/heartcare/activity/model/Intensity.java \
        backend/src/main/java/com/heartcare/activity/model/ActivityLog.java \
        backend/src/main/java/com/heartcare/activity/ActivityRepository.java \
        backend/src/test/java/com/heartcare/activity/ActivityRepositoryTest.java
git commit -m "feat(backend): add activity_logs table, entity, and repository (Slice 6)"
```

---

## Task 2: DTOs and service (validation, idempotency, history)

**Files:**
- Create: `backend/src/main/java/com/heartcare/activity/dto/ActivityLogRequest.java`
- Create: `backend/src/main/java/com/heartcare/activity/dto/ActivityLogResponse.java`
- Create: `backend/src/main/java/com/heartcare/activity/ActivityService.java`
- Test: `backend/src/test/java/com/heartcare/activity/ActivityServiceTest.java`

**Interfaces:**
- Consumes: `ActivityRepository`, `ActivityLog`, `ActivityType`, `Intensity` (Task 1); `com.heartcare.common.exception.BadRequestException`.
- Produces:
  - `ActivityLogRequest(Map<String,Object> data, OffsetDateTime measuredAt, String note, UUID clientRecordId)`.
  - `ActivityLogResponse(String id, Map<String,Object> data, OffsetDateTime measuredAt, String note, String clientRecordId, OffsetDateTime createdAt)`.
  - `ActivityService` with `ActivityLogResponse log(UUID userId, ActivityLogRequest request)` and `List<ActivityLogResponse> history(UUID userId, LocalDate from, LocalDate to)`.

- [ ] **Step 1: Write the failing service test**

Create `backend/src/test/java/com/heartcare/activity/ActivityServiceTest.java`:

```java
package com.heartcare.activity;

import com.heartcare.activity.dto.ActivityLogRequest;
import com.heartcare.activity.dto.ActivityLogResponse;
import com.heartcare.activity.model.ActivityLog;
import com.heartcare.common.exception.BadRequestException;
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
class ActivityServiceTest {

    @Mock
    ActivityRepository activityRepository;

    ActivityService service;

    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ActivityService(activityRepository);
    }

    private static Map<String, Object> validData() {
        Map<String, Object> data = new HashMap<>();
        data.put("type", "WALKING");
        data.put("durationMinutes", 30);
        data.put("intensity", "MODERATE");
        return data;
    }

    private ActivityLogRequest request(Map<String, Object> data, UUID crid) {
        return new ActivityLogRequest(data, null, null, crid);
    }

    @Test
    void logPersistsData() {
        when(activityRepository.save(any(ActivityLog.class))).thenAnswer(inv -> inv.getArgument(0));
        ActivityLogResponse response = service.log(userId, request(validData(), null));
        assertThat(response.data().get("type")).isEqualTo("WALKING");
        assertThat(response.data().get("durationMinutes")).isEqualTo(30);
    }

    @Test
    void logDefaultsMeasuredAtWhenNull() {
        when(activityRepository.save(any(ActivityLog.class))).thenAnswer(inv -> inv.getArgument(0));
        ActivityLogResponse response = service.log(userId, request(validData(), null));
        assertThat(response.measuredAt()).isNotNull();
    }

    @Test
    void logAcceptsOptionalStepsAndDistance() {
        when(activityRepository.save(any(ActivityLog.class))).thenAnswer(inv -> inv.getArgument(0));
        Map<String, Object> data = validData();
        data.put("steps", 3200);
        data.put("distanceMeters", 2400);
        ActivityLogResponse response = service.log(userId, request(data, null));
        assertThat(response.data().get("steps")).isEqualTo(3200);
    }

    @Test
    void logIsIdempotentOnClientRecordId() {
        UUID crid = UUID.randomUUID();
        ActivityLog existing = new ActivityLog();
        existing.setUserId(userId);
        existing.setData(Map.of("type", "CYCLING", "durationMinutes", 45, "intensity", "VIGOROUS"));
        existing.setMeasuredAt(OffsetDateTime.now());
        when(activityRepository.findByUserIdAndClientRecordId(userId, crid)).thenReturn(Optional.of(existing));

        ActivityLogResponse response = service.log(userId, request(validData(), crid));

        assertThat(response.data().get("type")).isEqualTo("CYCLING");
        verify(activityRepository, never()).save(any());
    }

    @Test
    void logRejectsMissingRequiredKey() {
        Map<String, Object> data = validData();
        data.remove("intensity");
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsUnknownKey() {
        Map<String, Object> data = validData();
        data.put("mood", "great");
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsBadTypeEnum() {
        Map<String, Object> data = validData();
        data.put("type", "SWIMMING");
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsBadIntensityEnum() {
        Map<String, Object> data = validData();
        data.put("intensity", "EXTREME");
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsOutOfRangeDuration() {
        Map<String, Object> data = validData();
        data.put("durationMinutes", 0);
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void logRejectsDurationThatTruncatesIntoRange() {
        Map<String, Object> data = validData();
        data.put("durationMinutes", 4294967326L); // (int) 4294967326L == 30, but true value is out of range
        assertThatThrownBy(() -> service.log(userId, request(data, null)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void historyDelegatesWithUtcDayBounds() {
        LocalDate from = LocalDate.of(2026, 7, 1);
        LocalDate to = LocalDate.of(2026, 7, 31);
        OffsetDateTime fromTs = OffsetDateTime.of(2026, 7, 1, 0, 0, 0, 0, ZoneOffset.UTC);
        OffsetDateTime toTs = OffsetDateTime.of(2026, 8, 1, 0, 0, 0, 0, ZoneOffset.UTC);
        when(activityRepository.findHistory(userId, fromTs, toTs)).thenReturn(List.of());

        service.history(userId, from, to);

        verify(activityRepository).findHistory(userId, fromTs, toTs);
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mvn test -Dtest=ActivityServiceTest`
Expected: FAIL — compilation error (`ActivityService`, `ActivityLogRequest`, `ActivityLogResponse` do not exist yet).

- [ ] **Step 3: Create the request DTO**

Create `backend/src/main/java/com/heartcare/activity/dto/ActivityLogRequest.java`:

```java
package com.heartcare.activity.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

public record ActivityLogRequest(
        @NotNull(message = "data is required")
        Map<String, Object> data,

        OffsetDateTime measuredAt,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        UUID clientRecordId) {
}
```

- [ ] **Step 4: Create the response DTO**

Create `backend/src/main/java/com/heartcare/activity/dto/ActivityLogResponse.java`:

```java
package com.heartcare.activity.dto;

import java.time.OffsetDateTime;
import java.util.Map;

public record ActivityLogResponse(
        String id,
        Map<String, Object> data,
        OffsetDateTime measuredAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
```

- [ ] **Step 5: Create the service**

Create `backend/src/main/java/com/heartcare/activity/ActivityService.java`. The allowed enum-value sets are derived from the Task 1 enums so they stay a single source of truth. Numeric validation uses `doubleValue()` (not an `int` cast) so a value that would truncate into range is still rejected.

```java
package com.heartcare.activity;

import com.heartcare.activity.dto.ActivityLogRequest;
import com.heartcare.activity.dto.ActivityLogResponse;
import com.heartcare.activity.model.ActivityLog;
import com.heartcare.activity.model.ActivityType;
import com.heartcare.activity.model.Intensity;
import com.heartcare.common.exception.BadRequestException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ActivityService {

    private static final Set<String> REQUIRED_KEYS = Set.of("type", "durationMinutes", "intensity");
    private static final Set<String> OPTIONAL_KEYS = Set.of("steps", "distanceMeters");

    // Allowed enum string values, derived from the model enums (single source of truth).
    private static final Set<String> ACTIVITY_TYPES = Arrays.stream(ActivityType.values())
            .map(Enum::name).collect(Collectors.toUnmodifiableSet());
    private static final Set<String> INTENSITIES = Arrays.stream(Intensity.values())
            .map(Enum::name).collect(Collectors.toUnmodifiableSet());

    // Sentinel bounds for open-ended date filters (safe within Postgres timestamptz range).
    private static final OffsetDateTime MIN_INSTANT = OffsetDateTime.of(1, 1, 1, 0, 0, 0, 0, ZoneOffset.UTC);
    private static final OffsetDateTime MAX_INSTANT = OffsetDateTime.of(9999, 12, 31, 0, 0, 0, 0, ZoneOffset.UTC);

    private final ActivityRepository activityRepository;

    public ActivityService(ActivityRepository activityRepository) {
        this.activityRepository = activityRepository;
    }

    @Transactional
    public ActivityLogResponse log(UUID userId, ActivityLogRequest request) {
        if (request.clientRecordId() != null) {
            var existing = activityRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        Map<String, Object> data = validate(request.data());

        ActivityLog log = new ActivityLog();
        log.setUserId(userId);
        log.setData(data);
        log.setMeasuredAt(request.measuredAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.measuredAt());
        log.setNote(request.note());
        log.setClientRecordId(request.clientRecordId());
        return toResponse(activityRepository.save(log));
    }

    @Transactional(readOnly = true)
    public List<ActivityLogResponse> history(UUID userId, LocalDate from, LocalDate to) {
        // Bucket calendar-date filters by UTC day; the query range is half-open [fromTs, toTs).
        OffsetDateTime fromTs = from == null ? MIN_INSTANT : from.atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        OffsetDateTime toTs = to == null ? MAX_INSTANT : to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        return activityRepository.findHistory(userId, fromTs, toTs)
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

        validateEnum(raw.get("type"), "type", ACTIVITY_TYPES);
        intInRange(raw.get("durationMinutes"), "durationMinutes", 1, 1440);
        validateEnum(raw.get("intensity"), "intensity", INTENSITIES);
        if (raw.containsKey("steps")) {
            intInRange(raw.get("steps"), "steps", 0, 100000);
        }
        if (raw.containsKey("distanceMeters")) {
            numberInRange(raw.get("distanceMeters"), "distanceMeters", 0, 100000);
        }
        return raw;
    }

    private void validateEnum(Object value, String field, Set<String> allowed) {
        if (!(value instanceof String s) || !allowed.contains(s)) {
            throw new BadRequestException(field + " must be one of " + allowed);
        }
    }

    private void intInRange(Object value, String field, int min, int max) {
        double d = numberInRange(value, field, min, max);
        if (d != Math.rint(d)) {
            throw new BadRequestException(field + " must be a whole number");
        }
    }

    private double numberInRange(Object value, String field, double min, double max) {
        if (!(value instanceof Number number)) {
            throw new BadRequestException(field + " must be a number");
        }
        double d = number.doubleValue();
        if (d < min || d > max) {
            throw new BadRequestException(field + " is out of range");
        }
        return d;
    }

    private ActivityLogResponse toResponse(ActivityLog log) {
        return new ActivityLogResponse(
                log.getId() == null ? null : log.getId().toString(),
                log.getData(),
                log.getMeasuredAt(),
                log.getNote(),
                log.getClientRecordId() == null ? null : log.getClientRecordId().toString(),
                log.getCreatedAt());
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `mvn test -Dtest=ActivityServiceTest`
Expected: PASS (11 tests).

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/java/com/heartcare/activity/dto/ActivityLogRequest.java \
        backend/src/main/java/com/heartcare/activity/dto/ActivityLogResponse.java \
        backend/src/main/java/com/heartcare/activity/ActivityService.java \
        backend/src/test/java/com/heartcare/activity/ActivityServiceTest.java
git commit -m "feat(backend): add ActivityService with validation and idempotency (Slice 6)"
```

---

## Task 3: Controller and end-to-end integration test

**Files:**
- Create: `backend/src/main/java/com/heartcare/activity/ActivityController.java`
- Test: `backend/src/test/java/com/heartcare/activity/ActivityControllerIntegrationTest.java`

**Interfaces:**
- Consumes: `ActivityService` (Task 2); `com.heartcare.common.response.ApiResponse`; `com.heartcare.common.security.UserPrincipal`; `com.heartcare.AbstractIntegrationTest`; the real `/api/v1/auth/register` endpoint (returns a JWT at `$.data.token`).
- Produces: `POST /api/v1/activities` and `GET /api/v1/activities?from=&to=`, both returning the `ApiResponse` envelope (`$.data...`).

- [ ] **Step 1: Write the failing integration test**

Create `backend/src/test/java/com/heartcare/activity/ActivityControllerIntegrationTest.java`:

```java
package com.heartcare.activity;

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

class ActivityControllerIntegrationTest extends AbstractIntegrationTest {

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

    private void postActivity(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk());
    }

    private static final String FULL = """
            { "data": {
                "type": "WALKING",
                "durationMinutes": 30,
                "intensity": "MODERATE",
                "steps": 3200,
                "distanceMeters": 2400
            }, "note": "morning walk" }""";

    @Test
    void unauthenticatedReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/activities")
                        .contentType(APPLICATION_JSON).content(FULL))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logThenHistoryReturnsActivity() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(FULL))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.data.type").value("WALKING"))
                .andExpect(jsonPath("$.data.data.durationMinutes").value(30))
                .andExpect(jsonPath("$.data.data.steps").value(3200))
                .andExpect(jsonPath("$.data.note").value("morning walk"));

        mockMvc.perform(get("/api/v1/activities").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].data.type").value("WALKING"))
                .andExpect(jsonPath("$.data[0].note").value("morning walk"));
    }

    @Test
    void minimalActivityRoundTrips() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "FARMING",
                                    "durationMinutes": 90,
                                    "intensity": "VIGOROUS"
                                } }"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.data.type").value("FARMING"))
                .andExpect(jsonPath("$.data.data.intensity").value("VIGOROUS"));
    }

    @Test
    void historyFiltersByDateRangeInUtc() throws Exception {
        String token = registerAndGetToken();
        // 23:30Z on 2026-07-10 is still 2026-07-10 in UTC; 00:30Z on 2026-07-11 is 2026-07-11.
        postActivity(token, withMeasuredAt("2026-07-10T23:30:00Z"));
        postActivity(token, withMeasuredAt("2026-07-11T00:30:00Z"));

        mockMvc.perform(get("/api/v1/activities?from=2026-07-11&to=2026-07-11")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].measuredAt").value(org.hamcrest.Matchers.startsWith("2026-07-11")));
    }

    private static String withMeasuredAt(String iso) {
        return """
                { "data": {
                    "type": "WALKING",
                    "durationMinutes": 30,
                    "intensity": "MODERATE"
                }, "measuredAt": "%s" }""".formatted(iso);
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String crid = UUID.randomUUID().toString();
        String body = """
                { "data": {
                    "type": "WALKING",
                    "durationMinutes": 30,
                    "intensity": "MODERATE"
                }, "clientRecordId": "%s" }""".formatted(crid);
        postActivity(token, body);
        postActivity(token, body);

        mockMvc.perform(get("/api/v1/activities").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void missingRequiredKeyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "WALKING",
                                    "durationMinutes": 30
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void badTypeEnumReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "SWIMMING",
                                    "durationMinutes": 30,
                                    "intensity": "MODERATE"
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void outOfRangeDurationReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "WALKING",
                                    "durationMinutes": 0,
                                    "intensity": "MODERATE"
                                } }"""))
                .andExpect(status().isBadRequest());
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mvn test -Dtest=ActivityControllerIntegrationTest`
Expected: FAIL — no handler for `/api/v1/activities` (the `ActivityController` does not exist), so the authenticated POSTs return 404/500 rather than the asserted results.

- [ ] **Step 3: Create the controller**

Create `backend/src/main/java/com/heartcare/activity/ActivityController.java`:

```java
package com.heartcare.activity;

import com.heartcare.activity.dto.ActivityLogRequest;
import com.heartcare.activity.dto.ActivityLogResponse;
import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
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
public class ActivityController {

    private final ActivityService activityService;

    public ActivityController(ActivityService activityService) {
        this.activityService = activityService;
    }

    @PostMapping("/activities")
    public ApiResponse<ActivityLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody ActivityLogRequest request) {
        return ApiResponse.ok(activityService.log(principal.userId(), request), "Activity logged");
    }

    @GetMapping("/activities")
    public ApiResponse<List<ActivityLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(activityService.history(principal.userId(), from, to));
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mvn test -Dtest=ActivityControllerIntegrationTest`
Expected: PASS (8 tests).

- [ ] **Step 5: Run the whole feature's tests together**

Run: `mvn test -Dtest=Activity*`
Expected: PASS — `ActivityRepositoryTest` (2), `ActivityServiceTest` (11), `ActivityControllerIntegrationTest` (8).

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/heartcare/activity/ActivityController.java \
        backend/src/test/java/com/heartcare/activity/ActivityControllerIntegrationTest.java
git commit -m "feat(backend): add activity endpoints with integration tests (Slice 6)"
```

---

## Task 4: Documentation

**Files:**
- Modify: `backend/README.md:34` (build-progress row for Slice 6)
- Modify: `backend/docs/API.md` (add Activity section)
- Modify: `backend/docs/DATABASE.md` (add `activity_logs` table + `V7` log entry)

**Interfaces:**
- Consumes: nothing (documentation only). Match the existing Slice-5 "Symptoms" formatting in each file.

- [ ] **Step 1: Flip the README build-progress row**

In `backend/README.md`, replace the Slice 6 row:

```markdown
| 6 | Activity | ⬜ Not started |
```

with:

```markdown
| 6 | Activity (log physical-activity sessions: type/duration/intensity + optional steps/distance, JSONB data) | ✅ Done |
```

- [ ] **Step 2: Add the Activity section to `backend/docs/API.md`**

Follow the existing "Symptoms" section format. Add a new section documenting both endpoints:

- `POST /api/v1/activities` — auth required; body `ActivityLogRequest` (`data`, optional `measuredAt`, optional `note` ≤ 500 chars, optional `clientRecordId`); idempotent on `clientRecordId`; returns `ApiResponse<ActivityLogResponse>`.
- `GET /api/v1/activities?from=&to=` — auth required; optional ISO-date `from`/`to` filtered on `measuredAt` by UTC day (half-open `[from, day-after-to)`); ordered `measuredAt` desc.
- `data` keys table: `type` (enum `WALKING|JOGGING|CYCLING|HOUSEHOLD|FARMING|STRETCHING|OTHER`, required), `durationMinutes` (int 1–1440, required), `intensity` (enum `LIGHT|MODERATE|VIGOROUS`, required), `steps` (int 0–100000, optional), `distanceMeters` (number 0–100000, optional).
- Note: the `type` and `intensity` enums are language-neutral codes; the client renders localized EN/AM labels. There is no server-computed field on an activity log.
- Include the request/response JSON examples from the design spec `docs/design/2026-07-16-activity-design.md` §5.

- [ ] **Step 3: Add the table to `backend/docs/DATABASE.md`**

Follow the existing `symptom_logs` entry format. Add:
- An `activity_logs` table description with its columns (`id`, `user_id`, `data` JSONB, `measured_at`, `note`, `client_record_id`, `created_at`), the `uq_activity_user_client_record` unique constraint, and the `idx_activity_user_measured` index. Note it has **no** assessment/severity column (this slice computes nothing).
- A migration-log entry: `V7__create_activity_logs.sql — activity session log (Slice 6)`.

- [ ] **Step 4: Verify the full suite is green**

Run: `mvn test`
Expected: PASS — all prior tests plus the 21 new Activity tests. (Docs changes don't affect tests; this confirms nothing regressed.)

- [ ] **Step 5: Commit**

```bash
git add backend/README.md backend/docs/API.md backend/docs/DATABASE.md
git commit -m "docs(backend): document Slice 6 activity endpoints and schema"
```

---

## Self-Review (completed while writing)

**Spec coverage** (against `docs/design/2026-07-16-activity-design.md`):
- FR-ACT-003 (log type/duration/intensity) → Task 2 validation + Task 3 `POST /activities`. ✅
- FR-ACT-006 (history) → Task 2 `history` + Task 3 `GET /activities`. ✅
- FR-ACT-007 raw `steps` captured (no progress computed) → Task 2 optional-key validation; Task 1/3 round-trip. ✅
- Idempotency (Decision 6) → Task 1 unique constraint + finder; Task 2 idempotent `log`; Task 3 re-POST test. ✅
- No server-computed value (Decision 2) → no `assessment`/`overall_severity` column, entity, or class anywhere. ✅
- Append-only (Decision 5) → only POST/GET; no update/delete. ✅
- UTC half-open date filtering → Task 2 `MIN_INSTANT`/`MAX_INSTANT` + `plusDays(1)`; Task 3 midnight-boundary test. ✅
- Guidance content (Decision 3) → correctly absent (client-side static, out of scope). ✅
- Curated enums (Decision 7) → Task 1 enums; Task 2 derives allowed sets from them; unknown-value tests in Tasks 2 & 3. ✅

**Placeholder scan:** none — every code step contains complete code; the docs task lists exact content to add.

**Type consistency:** `ActivityLog`, `ActivityService`, `ActivityRepository`, `ActivityLogRequest`/`Response`, `findByUserIdAndClientRecordId`, `findHistory`, `log`, `history` are named identically across all tasks and match the design spec §6. Response field order matches the DTO record and the `toResponse` mapping.
