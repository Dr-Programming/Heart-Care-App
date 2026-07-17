package com.heartcare.vitals;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.persistence.IdempotentSaver;
import com.heartcare.patient.PatientProfileRepository;
import com.heartcare.patient.model.PatientProfile;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.dto.VitalLogResponse;
import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
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
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VitalsServiceTest {

    @Mock
    VitalsRepository vitalsRepository;

    @Mock
    PatientProfileRepository profileRepository;

    @Mock
    IdempotentSaver saver;

    VitalsService service;

    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new VitalsService(vitalsRepository, profileRepository, new VitalThresholds(), saver);
        // Unit-test stand-in for IdempotentSaver: no real DB, so just hand back the entity being
        // saved, mirroring a successful (non-racing) insert.
        lenient().when(saver.saveOrGetExisting(any(), any(), any())).thenAnswer(inv -> inv.getArgument(2));
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
        VitalLogResponse response = service.log(userId,
                request(VitalType.BLOOD_PRESSURE, values("systolic", 190, "diastolic", 100), null));

        assertThat(response.flagged()).isTrue();
    }

    @Test
    void logComputesFlaggedFalseForNormalGlucose() {
        VitalLogResponse response = service.log(userId,
                request(VitalType.GLUCOSE, values("glucose", "5.5"), null));

        assertThat(response.flagged()).isFalse();
    }

    @Test
    void logInjectsBmiFromProfileHeight() {
        PatientProfile profile = new PatientProfile(userId);
        profile.setHeightCm(170);
        when(profileRepository.findById(userId)).thenReturn(Optional.of(profile));

        VitalLogResponse response = service.log(userId,
                request(VitalType.WEIGHT, values("weight", 72), null));

        // 72 / (1.70^2) = 24.913... -> 24.9
        assertThat(response.values().get("bmi")).isEqualByComparingTo("24.9");
    }

    @Test
    void logOmitsBmiWhenNoHeight() {
        when(profileRepository.findById(userId)).thenReturn(Optional.empty());

        VitalLogResponse response = service.log(userId,
                request(VitalType.WEIGHT, values("weight", 72), null));

        assertThat(response.values()).doesNotContainKey("bmi");
        assertThat(response.flagged()).isFalse();
    }

    @Test
    void logDefaultsMeasuredAtWhenNull() {
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
        verify(saver, never()).saveOrGetExisting(any(), any(), any());
    }

    @Test
    void logIgnoresClientSentBmi() {
        PatientProfile profile = new PatientProfile(userId);
        profile.setHeightCm(170);
        when(profileRepository.findById(userId)).thenReturn(Optional.of(profile));

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
        verify(saver, never()).saveOrGetExisting(any(), any(), any());
    }

    @Test
    void logRejectsExtraKey() {
        assertThatThrownBy(() -> service.log(userId,
                request(VitalType.BLOOD_PRESSURE, values("systolic", 120, "diastolic", 80, "extra", 1), null)))
                .isInstanceOf(BadRequestException.class);
        verify(saver, never()).saveOrGetExisting(any(), any(), any());
    }

    @Test
    void logAcceptsCholesterolWithThreeKeys() {
        VitalLogResponse response = service.log(userId,
                request(VitalType.CHOLESTEROL, values("ldl", "3.0", "hdl", "1.5", "total", "5.0"), null));
        assertThat(response.type()).isEqualTo(VitalType.CHOLESTEROL);
        assertThat(response.flagged()).isFalse();
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
        // Service buckets by UTC day into a half-open range: [from 00:00Z, day-after-to 00:00Z).
        OffsetDateTime fromTs = OffsetDateTime.of(2026, 7, 1, 0, 0, 0, 0, ZoneOffset.UTC);
        OffsetDateTime toTs = OffsetDateTime.of(2026, 8, 1, 0, 0, 0, 0, ZoneOffset.UTC);
        when(vitalsRepository.findHistory(userId, fromTs, toTs, VitalType.GLUCOSE)).thenReturn(List.of());

        service.history(userId, VitalType.GLUCOSE, from, to);

        verify(vitalsRepository).findHistory(userId, fromTs, toTs, VitalType.GLUCOSE);
    }
}
