package com.heartcare.admin;

import com.heartcare.admin.dto.AdminRecords;
import com.heartcare.admin.dto.AdminStatsResponse;
import com.heartcare.admin.dto.AdminStatsResponse.DayCount;
import com.heartcare.admin.dto.AdminUserDetail;
import com.heartcare.admin.dto.AdminUserSummary;
import com.heartcare.admin.dto.AdminUserSummary.RecordCounts;
import com.heartcare.admin.dto.PageResponse;
import com.heartcare.admin.repository.AdminActivityRepository;
import com.heartcare.admin.repository.AdminDoseLogRepository;
import com.heartcare.admin.repository.AdminMedicationRepository;
import com.heartcare.admin.repository.AdminPatientUserRepository;
import com.heartcare.admin.repository.AdminSymptomsRepository;
import com.heartcare.admin.repository.AdminVitalsRepository;
import com.heartcare.activity.model.ActivityLog;
import com.heartcare.auth.model.User;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.medication.model.DoseLog;
import com.heartcare.medication.model.DoseStatus;
import com.heartcare.medication.model.Medication;
import com.heartcare.patient.PatientProfileRepository;
import com.heartcare.patient.model.PatientProfile;
import com.heartcare.symptoms.model.Severity;
import com.heartcare.symptoms.model.SymptomLog;
import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.Collection;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import static com.heartcare.admin.AdminSpecs.all;
import static com.heartcare.admin.AdminSpecs.dateBetween;
import static com.heartcare.admin.AdminSpecs.fieldEquals;
import static com.heartcare.admin.AdminSpecs.fieldIn;
import static com.heartcare.admin.AdminSpecs.instantBetween;
import static com.heartcare.admin.AdminSpecs.userIs;

/**
 * Read-only queries behind the admin panel. Every method is readOnly and every response is a
 * purpose-built DTO, so no entity (and no credential hash) is ever serialized directly.
 */
@Service
@Transactional(readOnly = true)
public class AdminDataService {

    static final int CHART_DAYS = 30;

    private final AdminPatientUserRepository users;
    private final PatientProfileRepository profiles;
    private final AdminMedicationRepository medications;
    private final AdminDoseLogRepository doseLogs;
    private final AdminVitalsRepository vitals;
    private final AdminSymptomsRepository symptoms;
    private final AdminActivityRepository activities;

    public AdminDataService(AdminPatientUserRepository users,
                            PatientProfileRepository profiles,
                            AdminMedicationRepository medications,
                            AdminDoseLogRepository doseLogs,
                            AdminVitalsRepository vitals,
                            AdminSymptomsRepository symptoms,
                            AdminActivityRepository activities) {
        this.users = users;
        this.profiles = profiles;
        this.medications = medications;
        this.doseLogs = doseLogs;
        this.vitals = vitals;
        this.symptoms = symptoms;
        this.activities = activities;
    }

    // ---- dashboard ----------------------------------------------------------------------

    public AdminStatsResponse stats() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        LocalDate today = now.toLocalDate();
        LocalDate chartStart = today.minusDays(CHART_DAYS - 1L);
        OffsetDateTime chartSince = chartStart.atStartOfDay().atOffset(ZoneOffset.UTC);

        AdminStatsResponse.Totals totals = new AdminStatsResponse.Totals(
                users.count(), profiles.count(), medications.count(), doseLogs.count(),
                vitals.count(), symptoms.count(), activities.count());

        return new AdminStatsResponse(
                totals,
                users.countByCreatedAtAfter(now.minusDays(7)),
                users.countByCreatedAtAfter(now.minusDays(30)),
                vitals.count(AdminSpecs.<VitalLog>fieldEquals("flagged", true)),
                symptoms.count(AdminSpecs.<SymptomLog>fieldIn("overallSeverity", severitiesAtLeast(Severity.URGENT))),
                users.count(AdminSpecs.lockedAt(now)),
                fillDays(users.signupsPerDay(chartSince), chartStart, today),
                fillDays(users.recordsPerDay(chartSince), chartStart, today));
    }

    // ---- users ----------------------------------------------------------------------------

    public PageResponse<AdminUserSummary> listUsers(String query, Pageable pageable) {
        Page<User> page = users.findAll(all(AdminSpecs.userMatches(query)), pageable);
        List<UUID> ids = page.getContent().stream().map(User::getId).toList();
        Map<UUID, RecordCounts> counts = recordCounts(ids);
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        return PageResponse.of(page, u -> new AdminUserSummary(
                u.getId().toString(),
                u.getFullName(),
                maskPhone(u.getPhone()),
                u.getPreferredLanguage(),
                u.getCreatedAt(),
                isLocked(u, now),
                counts.getOrDefault(u.getId(), new RecordCounts(0, 0, 0, 0, 0))));
    }

    public AdminUserDetail getUser(UUID userId) {
        User user = requireUser(userId);
        RecordCounts counts = recordCounts(List.of(userId))
                .getOrDefault(userId, new RecordCounts(0, 0, 0, 0, 0));
        AdminUserDetail.Profile profile = profiles.findById(userId).map(AdminDataService::toProfile).orElse(null);
        return new AdminUserDetail(
                user.getId().toString(),
                user.getFullName(),
                user.getPhone(),
                user.getPreferredLanguage(),
                user.getRole(),
                user.getCreatedAt(),
                user.getFailedLoginAttempts(),
                user.getLockedUntil(),
                counts,
                profile);
    }

    // ---- per-patient and cross-patient record tables -------------------------------------

    public List<AdminRecords.Medication> medications(UUID userId) {
        requireUser(userId);
        Map<UUID, Map<DoseStatus, Long>> tallies = new HashMap<>();
        for (Object[] row : doseLogs.statusCountsByMedication(userId)) {
            tallies.computeIfAbsent((UUID) row[0], k -> new EnumMap<>(DoseStatus.class))
                    .put((DoseStatus) row[1], ((Number) row[2]).longValue());
        }
        return medications.findByUserIdOrderByCreatedAtDesc(userId).stream().map(m -> {
            Map<DoseStatus, Long> t = tallies.getOrDefault(m.getId(), Map.of());
            return new AdminRecords.Medication(
                    m.getId().toString(), m.getName(), m.getDoseMg(), m.getFrequency(),
                    m.getScheduleTimes(), m.isActive(), m.getCreatedAt(), m.getUpdatedAt(),
                    t.getOrDefault(DoseStatus.TAKEN, 0L),
                    t.getOrDefault(DoseStatus.MISSED, 0L),
                    t.getOrDefault(DoseStatus.SKIPPED, 0L));
        }).toList();
    }

    public PageResponse<AdminRecords.Dose> doseLogs(UUID userId, DoseStatus status, UUID medicationId,
                                                   LocalDate from, LocalDate to, Pageable pageable) {
        if (userId != null) {
            requireUser(userId);
        }
        Page<DoseLog> page = doseLogs.findAll(all(
                userIs(userId),
                fieldEquals("status", status),
                fieldEquals("medicationId", medicationId),
                dateBetween("scheduledDate", from, to)), pageable);
        Map<UUID, String> names = userNames(page.getContent().stream().map(DoseLog::getUserId).toList());
        Map<UUID, String> medNames = medications
                .findByIdIn(page.getContent().stream().map(DoseLog::getMedicationId).distinct().toList())
                .stream().collect(Collectors.toMap(Medication::getId, Medication::getName));
        return PageResponse.of(page, d -> new AdminRecords.Dose(
                d.getId().toString(), d.getUserId().toString(), names.get(d.getUserId()),
                d.getMedicationId().toString(), medNames.get(d.getMedicationId()),
                d.getScheduledDate(), d.getScheduledTime(), d.getStatus(), d.getLoggedAt(), d.getNote()));
    }

    public PageResponse<AdminRecords.Vital> vitals(UUID userId, VitalType type, Boolean flagged,
                                                  LocalDate from, LocalDate to, Pageable pageable) {
        if (userId != null) {
            requireUser(userId);
        }
        Page<VitalLog> page = vitals.findAll(all(
                userIs(userId),
                fieldEquals("type", type),
                fieldEquals("flagged", flagged),
                instantBetween("measuredAt", from, to)), pageable);
        Map<UUID, String> names = userNames(page.getContent().stream().map(VitalLog::getUserId).toList());
        return PageResponse.of(page, v -> new AdminRecords.Vital(
                v.getId().toString(), v.getUserId().toString(), names.get(v.getUserId()),
                v.getType(), v.getValues(), v.isFlagged(), v.getMeasuredAt(), v.getNote(), v.getCreatedAt()));
    }

    /** {@code minSeverity} keeps that level and everything more serious (Severity is ordinal-ranked). */
    public PageResponse<AdminRecords.Symptom> symptoms(UUID userId, Severity minSeverity,
                                                      LocalDate from, LocalDate to, Pageable pageable) {
        if (userId != null) {
            requireUser(userId);
        }
        Page<SymptomLog> page = symptoms.findAll(all(
                userIs(userId),
                minSeverity == null ? null : fieldIn("overallSeverity", severitiesAtLeast(minSeverity)),
                instantBetween("measuredAt", from, to)), pageable);
        Map<UUID, String> names = userNames(page.getContent().stream().map(SymptomLog::getUserId).toList());
        return PageResponse.of(page, s -> new AdminRecords.Symptom(
                s.getId().toString(), s.getUserId().toString(), names.get(s.getUserId()),
                s.getOverallSeverity(), s.getData(), s.getAssessment(),
                s.getMeasuredAt(), s.getNote(), s.getCreatedAt()));
    }

    public PageResponse<AdminRecords.Activity> activities(UUID userId, LocalDate from, LocalDate to,
                                                         Pageable pageable) {
        if (userId != null) {
            requireUser(userId);
        }
        Page<ActivityLog> page = activities.findAll(all(
                userIs(userId),
                instantBetween("measuredAt", from, to)), pageable);
        Map<UUID, String> names = userNames(page.getContent().stream().map(ActivityLog::getUserId).toList());
        return PageResponse.of(page, a -> new AdminRecords.Activity(
                a.getId().toString(), a.getUserId().toString(), names.get(a.getUserId()),
                a.getData(), a.getMeasuredAt(), a.getNote(), a.getCreatedAt()));
    }

    // ---- helpers --------------------------------------------------------------------------

    private User requireUser(UUID userId) {
        return users.findById(userId).orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    private Map<UUID, String> userNames(Collection<UUID> ids) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        return users.findByIdIn(Set.copyOf(ids)).stream()
                .collect(Collectors.toMap(User::getId, User::getFullName));
    }

    /** Five grouped COUNT queries for the whole page, rather than five per user. */
    private Map<UUID, RecordCounts> recordCounts(List<UUID> ids) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        Map<UUID, Long> meds = toCountMap(medications.countByUserIds(ids));
        Map<UUID, Long> doses = toCountMap(doseLogs.countByUserIds(ids));
        Map<UUID, Long> vit = toCountMap(vitals.countByUserIds(ids));
        Map<UUID, Long> sym = toCountMap(symptoms.countByUserIds(ids));
        Map<UUID, Long> act = toCountMap(activities.countByUserIds(ids));
        return ids.stream().collect(Collectors.toMap(Function.identity(), id -> new RecordCounts(
                meds.getOrDefault(id, 0L), doses.getOrDefault(id, 0L), vit.getOrDefault(id, 0L),
                sym.getOrDefault(id, 0L), act.getOrDefault(id, 0L))));
    }

    private static Map<UUID, Long> toCountMap(List<Object[]> rows) {
        return rows.stream().collect(Collectors.toMap(r -> (UUID) r[0], r -> ((Number) r[1]).longValue()));
    }

    private static List<Severity> severitiesAtLeast(Severity min) {
        return Arrays.stream(Severity.values()).filter(s -> s.compareTo(min) >= 0).toList();
    }

    /** One entry per day in [start, end], zero-filled, so the chart's x-axis has no gaps. */
    private static List<DayCount> fillDays(List<Object[]> rows, LocalDate start, LocalDate end) {
        Map<LocalDate, Long> byDay = new HashMap<>();
        for (Object[] row : rows) {
            byDay.put(toLocalDate(row[0]), ((Number) row[1]).longValue());
        }
        return start.datesUntil(end.plusDays(1))
                .map(day -> new DayCount(day, byDay.getOrDefault(day, 0L)))
                .toList();
    }

    private static LocalDate toLocalDate(Object value) {
        if (value instanceof LocalDate d) {
            return d;
        }
        if (value instanceof java.sql.Date d) {
            return d.toLocalDate();
        }
        throw new IllegalStateException("Unexpected date type from native query: " + value.getClass());
    }

    private static boolean isLocked(User user, OffsetDateTime now) {
        return user.getLockedUntil() != null && user.getLockedUntil().isAfter(now);
    }

    /** {@code +251912345678} becomes {@code +2519••••5678}: enough to tell rows apart, not to call. */
    static String maskPhone(String phone) {
        if (phone == null || phone.length() < 9) {
            return "••••";
        }
        return phone.substring(0, 5) + "••••" + phone.substring(phone.length() - 4);
    }

    private static AdminUserDetail.Profile toProfile(PatientProfile p) {
        return new AdminUserDetail.Profile(
                p.getBirthYear(), p.getPreferredLanguage(), p.getHeightCm(), p.getChdStage(),
                p.getDiseaseHistory(), p.getComorbidities(), p.getManagementPlan(), p.getGoals(),
                p.getCreatedAt(), p.getUpdatedAt());
    }
}
