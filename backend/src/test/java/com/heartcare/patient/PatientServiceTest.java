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
