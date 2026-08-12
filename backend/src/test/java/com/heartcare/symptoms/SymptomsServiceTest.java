package com.heartcare.symptoms;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.persistence.IdempotentSaver;
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
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SymptomsServiceTest {

    @Mock
    SymptomsRepository symptomsRepository;

    @Mock
    IdempotentSaver saver;

    SymptomsService service;

    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new SymptomsService(symptomsRepository, new SymptomAssessment(), saver);
        // Unit-test stand-in for IdempotentSaver: no real DB, so just hand back the entity being
        // saved, mirroring a successful (non-racing) insert.
        lenient().when(saver.saveOrGetExisting(any(), any(), any())).thenAnswer(inv -> inv.getArgument(2));
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
        service.log(userId, request(benignData(), null));

        org.mockito.ArgumentCaptor<SymptomLog> captor = org.mockito.ArgumentCaptor.forClass(SymptomLog.class);
        verify(saver).saveOrGetExisting(any(), any(), captor.capture());
        assertThat(captor.getValue().getOverallSeverity().name()).isEqualTo("NONE");
    }

    @Test
    void logDefaultsMeasuredAtWhenNull() {
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
        verify(saver, never()).saveOrGetExisting(any(), any(), any());
    }

    @Test
    void logIgnoresClientSentAssessment() {
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
    void logRejectsOutOfRangeHeartRateThatTruncatesIntoRange() {
        Map<String, Object> data = benignData();
        data.put("heartRate", 4294967316L); // (int) 4294967316L == 20, but true value is out of range
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
