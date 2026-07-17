package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.persistence.IdempotentSaver;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.dto.MedicationResponse;
import com.heartcare.medication.model.Frequency;
import com.heartcare.medication.model.Medication;
import org.junit.jupiter.api.BeforeEach;
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
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MedicationServiceTest {

    @Mock
    MedicationRepository repository;

    @Mock
    IdempotentSaver saver;

    @InjectMocks
    MedicationService service;

    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        // Unit-test stand-in for IdempotentSaver: no real DB, so just hand back the entity being
        // saved, mirroring a successful (non-racing) insert.
        lenient().when(saver.saveOrGetExisting(any(), any(), any())).thenAnswer(inv -> inv.getArgument(2));
    }

    private MedicationRequest request(UUID clientRecordId, Boolean active) {
        return new MedicationRequest("Aspirin", new BigDecimal("100.00"),
                Frequency.BID, List.of("08:00", "20:00"), active, clientRecordId);
    }

    @Test
    void createSavesAndReturnsMedication() {
        MedicationResponse response = service.create(userId, request(null, null));

        ArgumentCaptor<Medication> captor = ArgumentCaptor.forClass(Medication.class);
        verify(saver).saveOrGetExisting(any(), any(), captor.capture());
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
        verify(saver, never()).saveOrGetExisting(any(), any(), any());
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
