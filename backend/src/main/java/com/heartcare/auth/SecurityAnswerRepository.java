package com.heartcare.auth;

import com.heartcare.auth.model.SecurityAnswer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface SecurityAnswerRepository extends JpaRepository<SecurityAnswer, UUID> {

    List<SecurityAnswer> findByUserId(UUID userId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM SecurityAnswer a WHERE a.userId = :userId")
    void deleteByUserId(@Param("userId") UUID userId);
}
