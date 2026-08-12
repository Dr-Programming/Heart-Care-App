package com.heartcare.common.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Performs an insert in its own transaction so a UNIQUE-constraint violation can be caught
 * and recovered from by the caller.
 *
 * <p>This exists because of a JPA constraint that is easy to get wrong: once a constraint
 * violation occurs, Hibernate poisons the persistence context and marks the transaction
 * rollback-only. Catching the exception and re-reading <em>inside the same transaction</em>
 * fails too. REQUIRES_NEW confines the failure to an inner transaction, leaving the caller's
 * context clean and free to re-read the winning row. See docs/design/2026-07-17-sync-design.md §8.
 */
@Component
public class IdempotentWriter {

    /**
     * @return the saved entity
     * @throws org.springframework.dao.DataIntegrityViolationException if a constraint rejects the insert
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public <T> T insert(JpaRepository<T, ?> repo, T entity) {
        // saveAndFlush, not save: force the INSERT to execute here so the violation surfaces
        // inside this transaction where it can be caught, rather than later at commit time.
        return repo.saveAndFlush(entity);
    }
}
