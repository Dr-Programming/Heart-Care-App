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
