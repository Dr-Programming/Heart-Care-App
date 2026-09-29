package com.heartcare.research.repository;

import com.heartcare.research.model.Researcher;
import com.heartcare.research.model.ResearcherStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ResearcherRepository extends JpaRepository<Researcher, UUID> {

    Optional<Researcher> findByUsername(String username);

    boolean existsByUsername(String username);

    List<Researcher> findByStatusNotOrderByCreatedAtDesc(ResearcherStatus status);

    List<Researcher> findByStatusOrderByArchivedAtDesc(ResearcherStatus status);
}
