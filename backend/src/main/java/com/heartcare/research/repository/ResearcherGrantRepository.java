package com.heartcare.research.repository;

import com.heartcare.research.model.ResearcherGrant;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface ResearcherGrantRepository extends JpaRepository<ResearcherGrant, UUID> {
}
