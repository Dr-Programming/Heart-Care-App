package com.heartcare.patient;

import com.heartcare.common.persistence.IdempotentSaver;
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
    private final IdempotentSaver saver;

    public PatientService(PatientProfileRepository repository, IdempotentSaver saver) {
        this.repository = repository;
        this.saver = saver;
    }

    @Transactional(readOnly = true)
    public PatientProfileResponse getProfile(UUID userId) {
        return repository.findById(userId)
                .map(this::toResponse)
                .orElseGet(() -> emptyResponse(userId));
    }

    // Deliberately NOT @Transactional: the create-if-absent step runs in IdempotentSaver's
    // REQUIRES_NEW transaction so two concurrent first-time upserts cannot both insert the same
    // primary key and fail one of them with a 500. Same idiom as the log services (design §8).
    public PatientProfileResponse upsertProfile(UUID userId, PatientProfileRequest request) {
        PatientProfile profile = repository.findById(userId).orElseGet(() ->
                saver.saveOrGetExisting(repository, () -> repository.findById(userId),
                        new PatientProfile(userId)));
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
