package com.heartcare.auth;

import com.heartcare.auth.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByPhone(String phone);

    boolean existsByPhone(String phone);

    /**
     * Increments the failure counter and, on the attempt that reaches the limit, stamps the
     * lock — in one statement. A read-modify-write in Java would lose increments under the
     * parallel guessing this is meant to stop (Postgres defaults to READ COMMITTED).
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = """
            UPDATE users
               SET failed_login_attempts = failed_login_attempts + 1,
                   locked_until = CASE WHEN failed_login_attempts + 1 >= :maxAttempts
                                       THEN :lockUntil
                                       ELSE locked_until END
             WHERE id = :id
            """, nativeQuery = true)
    void recordFailedAttempt(@Param("id") UUID id,
                             @Param("maxAttempts") int maxAttempts,
                             @Param("lockUntil") OffsetDateTime lockUntil);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = "UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE id = :id",
            nativeQuery = true)
    void resetFailedAttempts(@Param("id") UUID id);
}
