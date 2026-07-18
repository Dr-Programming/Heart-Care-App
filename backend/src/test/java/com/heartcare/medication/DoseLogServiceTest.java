package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.persistence.IdempotentSaver;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.DoseLogResponse;
import com.heartcare.medication.model.DoseLog;
import com.heartcare.medication.model.DoseStatus;
import com.heartcare.medication.model.Medication;
import org.junit.jupiter.api.BeforeEach;
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
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DoseLogServiceTest {

    @Mock
    DoseLogRepository doseLogRepository;

    @Mock
    MedicationRepository medicationRepository;

    @Mock
    IdempotentSaver saver;

    @InjectMocks
    DoseLogService service;

    private final UUID userId = UUID.randomUUID();
    private final UUID medicationId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        // Unit-test stand-in for IdempotentSaver: no real DB, so just hand back the entity being
        // saved, mirroring a successful (non-racing) insert.
        lenient().when(saver.saveOrGetExisting(any(), any(), any())).thenAnswer(inv -> inv.getArgument(2));
    }

    private DoseLogRequest request(UUID clientRecordId) {
        return new DoseLogRequest(DoseStatus.TAKEN, LocalDate.of(2026, 7, 10),
                LocalTime.of(8, 0), OffsetDateTime.parse("2026-07-10T08:05:00Z"), "with food", clientRecordId);
    }

    @Test
    void logCreatesDoseAgainstOwnedMedication() {
        when(medicationRepository.findByIdAndUserId(medicationId, userId))
                .thenReturn(Optional.of(new Medication()));

        DoseLogResponse response = service.log(userId, medicationId, request(null));

        ArgumentCaptor<DoseLog> captor = ArgumentCaptor.forClass(DoseLog.class);
        verify(saver).saveOrGetExisting(any(), any(), captor.capture());
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
        verify(saver, never()).saveOrGetExisting(any(), any(), any());
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
        verify(saver, never()).saveOrGetExisting(any(), any(), any());
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
