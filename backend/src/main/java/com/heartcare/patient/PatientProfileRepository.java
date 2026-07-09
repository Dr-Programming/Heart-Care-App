package com.heartcare.patient;

import com.heartcare.patient.model.PatientProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface PatientProfileRepository extends JpaRepository<PatientProfile, UUID> {
}
