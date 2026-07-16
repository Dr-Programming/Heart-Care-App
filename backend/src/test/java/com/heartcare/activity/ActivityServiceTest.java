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
