# Slice 2 — Patient Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-patient profile the authenticated user can read and update via `GET/PUT /api/v1/patients/me`, persisted in a new `patient_profiles` table (with JSONB `comorbidities` and `goals`).

**Architecture:** New package-by-feature module `com.heartcare.patient`, following the Slice 1 auth module exactly (record DTOs, constructor-injected `@Service`, `ApiResponse<T>` envelope, `@AuthenticationPrincipal UserPrincipal`). A 1:1 `patient_profiles` table is keyed by `user_id` (PK + FK to `users`). No profile row exists until the first `PUT` — `GET` returns a 200 all-null skeleton until then (lazy upsert). The feature is decoupled from `auth`: it never imports auth classes and stores only profile fields; identity comes from the JWT.

**Tech Stack:** Java 21, Spring Boot 4.1.0 (Spring Framework 7 / Hibernate 7), Spring Data JPA, Bean Validation, Flyway, PostgreSQL 16, JUnit 5 + Mockito + Testcontainers.

## Global Constraints

- Base path `/api/v1`; all endpoints return the `ApiResponse<T>` envelope (`common/response/ApiResponse`).
- `spring.jpa.hibernate.ddl-auto=validate` — the JPA entity MUST match the Flyway schema exactly. Flyway owns the schema; never edit an applied migration.
- Features never import from each other directly — the `patient` package must NOT import anything from `com.heartcare.auth`. Shared infra (`common/`) and the JWT `UserPrincipal` are allowed.
- DTOs are Java `record`s and stay inside the `patient` package.
- No new Maven dependencies — JSONB uses Hibernate's built-in `@JdbcTypeCode(SqlTypes.JSON)` (Jackson-backed).
- Commit messages: no AI co-author trailer.
- Build/test from the `backend/` directory: `mvn test` (Docker must be running for Testcontainers).

---

## File Structure

**Create:**
- `backend/src/main/resources/db/migration/V2__create_patient_profiles.sql` — the table.
- `backend/src/main/java/com/heartcare/patient/model/Goals.java` — JSONB value object (record), shared by entity + DTOs.
- `backend/src/main/java/com/heartcare/patient/model/PatientProfile.java` — `@Entity`.
- `backend/src/main/java/com/heartcare/patient/PatientProfileRepository.java` — `JpaRepository<PatientProfile, UUID>`.
- `backend/src/main/java/com/heartcare/patient/dto/PatientProfileRequest.java` — inbound record + validation.
- `backend/src/main/java/com/heartcare/patient/dto/PatientProfileResponse.java` — outbound record.
- `backend/src/main/java/com/heartcare/patient/PatientService.java` — `getProfile` / `upsertProfile`.
- `backend/src/main/java/com/heartcare/patient/PatientController.java` — `GET/PUT /patients/me`.
- `backend/src/test/java/com/heartcare/patient/PatientServiceTest.java` — unit tests (mocked repo).
- `backend/src/test/java/com/heartcare/patient/PatientControllerIntegrationTest.java` — Testcontainers + MockMvc.

**Modify:**
- `backend/README.md` — flip Slice 2 to ✅.
- `backend/docs/API.md` — document the two endpoints.
- `backend/docs/DATABASE.md` — document the `patient_profiles` table + `V2` log entry.

**No change needed:** `SecurityConfig` already gates everything except register/login with `.anyRequest().authenticated()`, so `/patients/me` is protected automatically.

---

### Task 1: Migration `V2__create_patient_profiles.sql`

Creates the table so Hibernate `validate` and the integration tests have a schema. This task's deliverable is verified by a repository round-trip test.

**Files:**
- Create: `backend/src/main/resources/db/migration/V2__create_patient_profiles.sql`
- Test: `backend/src/test/java/com/heartcare/patient/PatientProfileRepositoryTest.java`

**Interfaces:**
- Consumes: `users(id)` from `V1__create_users.sql`.
- Produces: table `patient_profiles` with columns `user_id, birth_year, preferred_language, height_cm, chd_stage, disease_history, comorbidities, management_plan, goals, created_at, updated_at`.

Note: the repository test in this task references `PatientProfile` and `Goals` (Task 2) and `PatientProfileRepository` (Task 3). If executing strictly in order, write Task 1's SQL, then implement Tasks 2–3, then return to run this test. Recommended: treat Tasks 1–3 as one commit group — write the SQL and entity/repository, then run this test. The steps below are ordered for that grouping.

- [ ] **Step 1: Write the migration SQL**

Create `backend/src/main/resources/db/migration/V2__create_patient_profiles.sql`:

```sql
CREATE TABLE patient_profiles (
    user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    birth_year         INTEGER,
    preferred_language VARCHAR(5),
    height_cm          INTEGER,
    chd_stage          VARCHAR(50),
    disease_history    TEXT,
    comorbidities      JSONB NOT NULL DEFAULT '[]'::jsonb,
    management_plan    TEXT,
    goals              JSONB,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- [ ] **Step 2: Proceed to Tasks 2 and 3** to create `Goals`, `PatientProfile`, and `PatientProfileRepository`, then come back for Step 3.

- [ ] **Step 3: Write the repository round-trip test**

Create `backend/src/test/java/com/heartcare/patient/PatientProfileRepositoryTest.java`. This also seeds a real `users` row first (FK constraint) using a JDBC insert via the autowired `JdbcTemplate` so we don't import the auth module.

```java
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mvn test -Dtest=PatientProfileRepositoryTest`
Expected: PASS (Flyway applies V2 on the Testcontainer; JSONB round-trips). If Hibernate throws a schema-validation error, the entity mapping in Task 2 doesn't match the SQL — fix the mismatch.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/resources/db/migration/V2__create_patient_profiles.sql \
        backend/src/main/java/com/heartcare/patient/ \
        backend/src/test/java/com/heartcare/patient/PatientProfileRepositoryTest.java
git commit -m "feat(backend): add patient_profiles table, entity, and repository (Slice 2)"
```

---

### Task 2: `Goals` value object and `PatientProfile` entity

**Files:**
- Create: `backend/src/main/java/com/heartcare/patient/model/Goals.java`
- Create: `backend/src/main/java/com/heartcare/patient/model/PatientProfile.java`
- (Tested via Task 1's repository test and Task 3's repository.)

**Interfaces:**
- Produces:
  - `record Goals(Integer bpSystolic, Integer bpDiastolic, Integer totalCholesterol, Integer stepsPerDay, Integer targetWeightKg, String dietNote)`
  - `class PatientProfile` with constructor `PatientProfile(UUID userId)`; getters/setters for `userId` (getter only), `birthYear`, `preferredLanguage`, `heightCm`, `chdStage`, `diseaseHistory`, `comorbidities` (`List<String>`), `managementPlan`, `goals` (`Goals`), `createdAt`, `updatedAt` (getters only for the timestamps).

- [ ] **Step 1: Create the `Goals` record**

Create `backend/src/main/java/com/heartcare/patient/model/Goals.java`:

```java
package com.heartcare.patient.model;

public record Goals(
        Integer bpSystolic,
        Integer bpDiastolic,
        Integer totalCholesterol,
        Integer stepsPerDay,
        Integer targetWeightKg,
        String dietNote) {
}
```

- [ ] **Step 2: Create the `PatientProfile` entity**

Create `backend/src/main/java/com/heartcare/patient/model/PatientProfile.java`. `user_id` is an assigned identifier (not generated) — it equals the authenticated user's id. `comorbidities` and `goals` map to JSONB via `@JdbcTypeCode(SqlTypes.JSON)`.

```java
package com.heartcare.patient.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "patient_profiles")
public class PatientProfile {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "birth_year")
    private Integer birthYear;

    @Column(name = "preferred_language", length = 5)
    private String preferredLanguage;

    @Column(name = "height_cm")
    private Integer heightCm;

    @Column(name = "chd_stage", length = 50)
    private String chdStage;

    @Column(name = "disease_history")
    private String diseaseHistory;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "comorbidities", nullable = false)
    private List<String> comorbidities = new ArrayList<>();

    @Column(name = "management_plan")
    private String managementPlan;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "goals")
    private Goals goals;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected PatientProfile() {
        // for JPA
    }

    public PatientProfile(UUID userId) {
        this.userId = userId;
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

    public UUID getUserId() {
        return userId;
    }

    public Integer getBirthYear() {
        return birthYear;
    }

    public void setBirthYear(Integer birthYear) {
        this.birthYear = birthYear;
    }

    public String getPreferredLanguage() {
        return preferredLanguage;
    }

    public void setPreferredLanguage(String preferredLanguage) {
        this.preferredLanguage = preferredLanguage;
    }

    public Integer getHeightCm() {
        return heightCm;
    }

    public void setHeightCm(Integer heightCm) {
        this.heightCm = heightCm;
    }

    public String getChdStage() {
        return chdStage;
    }

    public void setChdStage(String chdStage) {
        this.chdStage = chdStage;
    }

    public String getDiseaseHistory() {
        return diseaseHistory;
    }

    public void setDiseaseHistory(String diseaseHistory) {
        this.diseaseHistory = diseaseHistory;
    }

    public List<String> getComorbidities() {
        return comorbidities;
    }

    public void setComorbidities(List<String> comorbidities) {
        this.comorbidities = (comorbidities == null) ? new ArrayList<>() : comorbidities;
    }

    public String getManagementPlan() {
        return managementPlan;
    }

    public void setManagementPlan(String managementPlan) {
        this.managementPlan = managementPlan;
    }

    public Goals getGoals() {
        return goals;
    }

    public void setGoals(Goals goals) {
        this.goals = goals;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
```

- [ ] **Step 3: Verify compilation**

Run: `mvn -q compile`
Expected: BUILD SUCCESS (no test run yet; this just confirms the entity compiles).

(Committed together with Task 1 and Task 3.)

---

### Task 3: `PatientProfileRepository`

**Files:**
- Create: `backend/src/main/java/com/heartcare/patient/PatientProfileRepository.java`

**Interfaces:**
- Consumes: `PatientProfile` (Task 2).
- Produces: `interface PatientProfileRepository extends JpaRepository<PatientProfile, UUID>` — provides `findById(UUID)`, `save(...)`, `saveAndFlush(...)`.

- [ ] **Step 1: Create the repository**

Create `backend/src/main/java/com/heartcare/patient/PatientProfileRepository.java`:

```java
package com.heartcare.patient;

import com.heartcare.patient.model.PatientProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface PatientProfileRepository extends JpaRepository<PatientProfile, UUID> {
}
```

- [ ] **Step 2: Run Task 1's repository test now that entity + repo exist**

Run: `mvn test -Dtest=PatientProfileRepositoryTest`
Expected: PASS. Then perform Task 1 Step 5 (commit Tasks 1–3 together).

---

### Task 4: DTOs — `PatientProfileRequest` and `PatientProfileResponse`

**Files:**
- Create: `backend/src/main/java/com/heartcare/patient/dto/PatientProfileRequest.java`
- Create: `backend/src/main/java/com/heartcare/patient/dto/PatientProfileResponse.java`

**Interfaces:**
- Consumes: `Goals` (Task 2).
- Produces:
  - `record PatientProfileRequest(Integer birthYear, String preferredLanguage, Integer heightCm, String chdStage, String diseaseHistory, List<String> comorbidities, String managementPlan, Goals goals)` with Bean Validation constraints.
  - `record PatientProfileResponse(String userId, Integer birthYear, String preferredLanguage, Integer heightCm, String chdStage, String diseaseHistory, List<String> comorbidities, String managementPlan, Goals goals)`.

- [ ] **Step 1: Create `PatientProfileRequest`**

Create `backend/src/main/java/com/heartcare/patient/dto/PatientProfileRequest.java`. All fields optional (nullable); constraints only fire when a value is present.

```java
package com.heartcare.patient.dto;

import com.heartcare.patient.model.Goals;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public record PatientProfileRequest(
        @Min(value = 1900, message = "birthYear must be 1900 or later")
        @Max(value = 2100, message = "birthYear is out of range")
        Integer birthYear,

        @Pattern(regexp = "en|am", message = "preferredLanguage must be 'en' or 'am'")
        String preferredLanguage,

        @Min(value = 50, message = "heightCm must be at least 50")
        @Max(value = 250, message = "heightCm must be at most 250")
        Integer heightCm,

        @Size(max = 50, message = "chdStage must be at most 50 characters")
        String chdStage,

        String diseaseHistory,

        List<String> comorbidities,

        String managementPlan,

        Goals goals) {
}
```

Note: `birthYear` upper bound uses a constant `@Max(2100)` (Bean Validation constants must be compile-time literals; "current year" can't be an annotation argument). 2100 is a safe sanity ceiling; a tighter "not in the future" check is out of scope for this slice.

- [ ] **Step 2: Create `PatientProfileResponse`**

Create `backend/src/main/java/com/heartcare/patient/dto/PatientProfileResponse.java`:

```java
package com.heartcare.patient.dto;

import com.heartcare.patient.model.Goals;

import java.util.List;

public record PatientProfileResponse(
        String userId,
        Integer birthYear,
        String preferredLanguage,
        Integer heightCm,
        String chdStage,
        String diseaseHistory,
        List<String> comorbidities,
        String managementPlan,
        Goals goals) {
}
```

- [ ] **Step 3: Verify compilation**

Run: `mvn -q compile`
Expected: BUILD SUCCESS.

- [ ] **Step 4: Commit**

```bash
git add backend/src/main/java/com/heartcare/patient/dto/
git commit -m "feat(backend): add patient profile request/response DTOs (Slice 2)"
```

---

### Task 5: `PatientService` — get + upsert

**Files:**
- Create: `backend/src/main/java/com/heartcare/patient/PatientService.java`
- Test: `backend/src/test/java/com/heartcare/patient/PatientServiceTest.java`

**Interfaces:**
- Consumes: `PatientProfileRepository` (Task 3), `PatientProfile` + `Goals` (Task 2), `PatientProfileRequest` + `PatientProfileResponse` (Task 4).
- Produces:
  - `PatientProfileResponse getProfile(UUID userId)` — returns the saved profile, or an all-null skeleton (only `userId` set) if none exists.
  - `PatientProfileResponse upsertProfile(UUID userId, PatientProfileRequest request)` — creates the row if absent, otherwise updates it; returns the saved state.

- [ ] **Step 1: Write the failing unit tests**

Create `backend/src/test/java/com/heartcare/patient/PatientServiceTest.java`:

```java
package com.heartcare.patient;

import com.heartcare.patient.dto.PatientProfileRequest;
import com.heartcare.patient.dto.PatientProfileResponse;
import com.heartcare.patient.model.Goals;
import com.heartcare.patient.model.PatientProfile;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PatientServiceTest {

    @Mock
    PatientProfileRepository repository;

    @InjectMocks
    PatientService service;

    private final UUID userId = UUID.randomUUID();

    @Test
    void getProfileReturnsEmptySkeletonWhenNoneExists() {
        when(repository.findById(userId)).thenReturn(Optional.empty());

        PatientProfileResponse response = service.getProfile(userId);

        assertThat(response.userId()).isEqualTo(userId.toString());
        assertThat(response.birthYear()).isNull();
        assertThat(response.comorbidities()).isEmpty();
        assertThat(response.goals()).isNull();
        verify(repository, never()).save(any());
    }

    @Test
    void upsertCreatesProfileWhenNoneExists() {
        when(repository.findById(userId)).thenReturn(Optional.empty());
        when(repository.save(any(PatientProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        PatientProfileRequest request = new PatientProfileRequest(
                1975, "am", 172, "Stage II", "history",
                List.of("diabetes"), "plan", new Goals(120, 80, 180, 8000, 70, "low salt"));

        PatientProfileResponse response = service.upsertProfile(userId, request);

        ArgumentCaptor<PatientProfile> captor = ArgumentCaptor.forClass(PatientProfile.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getUserId()).isEqualTo(userId);
        assertThat(captor.getValue().getComorbidities()).containsExactly("diabetes");
        assertThat(response.preferredLanguage()).isEqualTo("am");
        assertThat(response.goals().stepsPerDay()).isEqualTo(8000);
    }

    @Test
    void upsertUpdatesExistingProfile() {
        PatientProfile existing = new PatientProfile(userId);
        existing.setPreferredLanguage("en");
        when(repository.findById(userId)).thenReturn(Optional.of(existing));
        when(repository.save(any(PatientProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        PatientProfileRequest request = new PatientProfileRequest(
                1980, "am", 165, null, null, List.of(), null, null);

        PatientProfileResponse response = service.upsertProfile(userId, request);

        assertThat(response.preferredLanguage()).isEqualTo("am");
        assertThat(response.birthYear()).isEqualTo(1980);
        verify(repository).save(existing);
    }

    @Test
    void upsertWithNullComorbiditiesStoresEmptyList() {
        when(repository.findById(userId)).thenReturn(Optional.empty());
        when(repository.save(any(PatientProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        PatientProfileRequest request = new PatientProfileRequest(
                null, null, null, null, null, null, null, null);

        PatientProfileResponse response = service.upsertProfile(userId, request);

        assertThat(response.comorbidities()).isEmpty();
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mvn test -Dtest=PatientServiceTest`
Expected: FAIL — compilation error (`PatientService` does not exist).

- [ ] **Step 3: Implement `PatientService`**

Create `backend/src/main/java/com/heartcare/patient/PatientService.java`:

```java
package com.heartcare.patient;

import com.heartcare.patient.dto.PatientProfileRequest;
import com.heartcare.patient.dto.PatientProfileResponse;
import com.heartcare.patient.model.PatientProfile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class PatientService {

    private final PatientProfileRepository repository;

    public PatientService(PatientProfileRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public PatientProfileResponse getProfile(UUID userId) {
        return repository.findById(userId)
                .map(this::toResponse)
                .orElseGet(() -> emptyResponse(userId));
    }

    @Transactional
    public PatientProfileResponse upsertProfile(UUID userId, PatientProfileRequest request) {
        PatientProfile profile = repository.findById(userId)
                .orElseGet(() -> new PatientProfile(userId));
        profile.setBirthYear(request.birthYear());
        profile.setPreferredLanguage(request.preferredLanguage());
        profile.setHeightCm(request.heightCm());
        profile.setChdStage(request.chdStage());
        profile.setDiseaseHistory(request.diseaseHistory());
        profile.setComorbidities(request.comorbidities() == null
                ? new ArrayList<>() : new ArrayList<>(request.comorbidities()));
        profile.setManagementPlan(request.managementPlan());
        profile.setGoals(request.goals());
        PatientProfile saved = repository.save(profile);
        return toResponse(saved);
    }

    private PatientProfileResponse toResponse(PatientProfile p) {
        return new PatientProfileResponse(
                p.getUserId().toString(),
                p.getBirthYear(),
                p.getPreferredLanguage(),
                p.getHeightCm(),
                p.getChdStage(),
                p.getDiseaseHistory(),
                p.getComorbidities(),
                p.getManagementPlan(),
                p.getGoals());
    }

    private PatientProfileResponse emptyResponse(UUID userId) {
        return new PatientProfileResponse(
                userId.toString(), null, null, null, null, null,
                List.of(), null, null);
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mvn test -Dtest=PatientServiceTest`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/heartcare/patient/PatientService.java \
        backend/src/test/java/com/heartcare/patient/PatientServiceTest.java
git commit -m "feat(backend): add PatientService get/upsert with unit tests (Slice 2)"
```

---

### Task 6: `PatientController` — `GET/PUT /patients/me`

**Files:**
- Create: `backend/src/main/java/com/heartcare/patient/PatientController.java`
- Test: `backend/src/test/java/com/heartcare/patient/PatientControllerIntegrationTest.java`

**Interfaces:**
- Consumes: `PatientService` (Task 5), `ApiResponse` (`common/response`), `UserPrincipal` (`common/security`).
- Produces: HTTP `GET /api/v1/patients/me` and `PUT /api/v1/patients/me`, both returning `ApiResponse<PatientProfileResponse>`.

- [ ] **Step 1: Write the failing integration tests**

Create `backend/src/test/java/com/heartcare/patient/PatientControllerIntegrationTest.java`. It registers a user through the real auth endpoint to obtain a token (black-box; no auth classes imported), then exercises the profile endpoints.

```java
package com.heartcare.patient;

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

class PatientControllerIntegrationTest extends AbstractIntegrationTest {

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

    /** Registers a fresh user via the real auth endpoint and returns its JWT. */
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

    @Test
    void getProfileWithoutTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/patients/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void getProfileBeforeAnySaveReturnsEmptySkeleton() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(get("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.userId").exists())
                .andExpect(jsonPath("$.data.birthYear").doesNotExist())
                .andExpect(jsonPath("$.data.comorbidities").isArray())
                .andExpect(jsonPath("$.data.comorbidities").isEmpty());
    }

    @Test
    void putThenGetReturnsSavedProfile() throws Exception {
        String token = registerAndGetToken();

        String putBody = """
                {
                  "birthYear": 1975,
                  "preferredLanguage": "am",
                  "heightCm": 172,
                  "chdStage": "Stage II",
                  "diseaseHistory": "prior MI",
                  "comorbidities": ["diabetes", "hypertension"],
                  "managementPlan": "statin + aspirin",
                  "goals": { "bpSystolic": 120, "bpDiastolic": 80, "totalCholesterol": 180,
                             "stepsPerDay": 8000, "targetWeightKg": 70, "dietNote": "low salt" }
                }
                """;

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(putBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.preferredLanguage").value("am"))
                .andExpect(jsonPath("$.data.goals.stepsPerDay").value(8000));

        mockMvc.perform(get("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.birthYear").value(1975))
                .andExpect(jsonPath("$.data.comorbidities[0]").value("diabetes"))
                .andExpect(jsonPath("$.data.goals.dietNote").value("low salt"));
    }

    @Test
    void putIsIdempotentAndUpdatesInPlace() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"preferredLanguage\": \"en\" }"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"preferredLanguage\": \"am\", \"birthYear\": 1990 }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.preferredLanguage").value("am"))
                .andExpect(jsonPath("$.data.birthYear").value(1990));
    }

    @Test
    void putWithInvalidLanguageReturns400() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"preferredLanguage\": \"fr\" }"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void putWithOutOfRangeHeightReturns400() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"heightCm\": 500 }"))
                .andExpect(status().isBadRequest());
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mvn test -Dtest=PatientControllerIntegrationTest`
Expected: FAIL — 404s (controller not mapped) / compilation error (`PatientController` missing).

- [ ] **Step 3: Implement `PatientController`**

Create `backend/src/main/java/com/heartcare/patient/PatientController.java`:

```java
package com.heartcare.patient;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.patient.dto.PatientProfileRequest;
import com.heartcare.patient.dto.PatientProfileResponse;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {

    private final PatientService patientService;

    public PatientController(PatientService patientService) {
        this.patientService = patientService;
    }

    @GetMapping("/me")
    public ApiResponse<PatientProfileResponse> getMyProfile(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ApiResponse.ok(patientService.getProfile(principal.userId()));
    }

    @PutMapping("/me")
    public ApiResponse<PatientProfileResponse> updateMyProfile(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody PatientProfileRequest request) {
        return ApiResponse.ok(patientService.upsertProfile(principal.userId(), request), "Profile saved");
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mvn test -Dtest=PatientControllerIntegrationTest`
Expected: PASS (6 tests). Requires Docker running for Testcontainers.

- [ ] **Step 5: Run the full suite to confirm no regressions**

Run: `mvn test`
Expected: PASS — all Slice 1 auth tests plus the new patient tests are green.

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/heartcare/patient/PatientController.java \
        backend/src/test/java/com/heartcare/patient/PatientControllerIntegrationTest.java
git commit -m "feat(backend): add GET/PUT /patients/me endpoints with integration tests (Slice 2)"
```

---

### Task 7: Documentation

**Files:**
- Modify: `backend/README.md`
- Modify: `backend/docs/API.md`
- Modify: `backend/docs/DATABASE.md`

**Interfaces:** none (docs only).

- [ ] **Step 1: Update the README build-progress table**

In `backend/README.md`, change the Slice 2 row from `⬜ Not started` to `✅ Done`:

```markdown
| 2 | Patient profile (GET/PUT /patients/me, profile + goals JSONB) | ✅ Done |
```

- [ ] **Step 2: Add the endpoints to `API.md`**

Append a "Patient Profile" section to `backend/docs/API.md` documenting both endpoints. Match the existing formatting; include auth requirement, request body, and the `ApiResponse` envelope example:

```markdown
## Patient Profile

All endpoints require `Authorization: Bearer <JWT>`. Base path `/api/v1`.

### GET /patients/me
Returns the authenticated patient's profile. If no profile has been saved yet,
returns a 200 with an all-null skeleton (`comorbidities` is `[]`, `goals` is `null`).

Response `data`:
```json
{
  "userId": "…uuid…",
  "birthYear": 1975,
  "preferredLanguage": "am",
  "heightCm": 172,
  "chdStage": "Stage II",
  "diseaseHistory": "prior MI",
  "comorbidities": ["diabetes", "hypertension"],
  "managementPlan": "statin + aspirin",
  "goals": {
    "bpSystolic": 120, "bpDiastolic": 80, "totalCholesterol": 180,
    "stepsPerDay": 8000, "targetWeightKg": 70, "dietNote": "low salt"
  }
}
```

### PUT /patients/me
Creates or replaces the authenticated patient's profile (upsert). Request body is
the same object as above minus `userId`. All fields optional. Validation:
`birthYear` 1900–2100, `preferredLanguage` ∈ {`en`,`am`}, `heightCm` 50–250,
`chdStage` ≤ 50 chars. Invalid input → `400`. Returns the saved profile.
```

- [ ] **Step 3: Add the table to `DATABASE.md`**

Append a `patient_profiles` entry to `backend/docs/DATABASE.md`, plus a `V2` migration-log line. Match the existing table-description style:

```markdown
### patient_profiles (V2)
One row per patient (1:1 with `users`). `user_id` is both PK and FK to `users(id)`
(`ON DELETE CASCADE`). JSONB columns: `comorbidities` (string array),
`goals` (BP/cholesterol/steps/weight/diet object).

| Column | Type | Notes |
|---|---|---|
| user_id | UUID | PK, FK → users(id) |
| birth_year | INTEGER | year only |
| preferred_language | VARCHAR(5) | `en` / `am` |
| height_cm | INTEGER | for BMI (Vitals slice) |
| chd_stage | VARCHAR(50) | |
| disease_history | TEXT | |
| comorbidities | JSONB | default `[]` |
| management_plan | TEXT | |
| goals | JSONB | nullable |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Migration log:** `V2__create_patient_profiles.sql` — adds `patient_profiles`.
```

Adjust wording/placement to fit the existing document structure.

- [ ] **Step 4: Commit**

```bash
git add backend/README.md backend/docs/API.md backend/docs/DATABASE.md
git commit -m "docs(backend): document Slice 2 patient profile endpoints and schema"
```

---

## Verification (end of slice)

- [ ] `mvn test` from `backend/` is fully green (Slice 1 + Slice 2, Docker running).
- [ ] `mvn spring-boot:run` boots and Flyway applies `V2` on top of `V1` (manual smoke, optional).
- [ ] `git log --oneline` shows the Slice 2 commits; working tree clean.
- [ ] Re-index the graph (`detect_changes()` / `index_repository`) so the new `patient` package is searchable.

## Notes on likely failure points

- **Hibernate schema-validation error on boot/tests:** the entity column types don't match `V2`. Most common: using `Short` vs `Integer`, or a `@Column(name=...)` typo. The migration is the source of truth — align the entity to it.
- **JSONB mapping error (`Goals` won't serialize):** ensure `@JdbcTypeCode(SqlTypes.JSON)` is on both `comorbidities` and `goals`, imported from `org.hibernate.annotations` / `org.hibernate.type`. No extra Maven dependency is needed — Hibernate 7 serializes via the app's Jackson `ObjectMapper`.
- **Assigned-id upsert double row / StaleObjectState:** the service always `findById` first and reuses the managed entity, so `save()` updates rather than inserts a duplicate. Don't switch to blind `new PatientProfile(...)` on update.
- **Validation not firing:** the `@Valid` on the controller `@RequestBody` is required for the `400` tests to pass.
