package com.heartcare.common.persistence;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.function.Supplier;

/**
 * Inserts an entity idempotently: when a concurrent writer wins the race and this insert violates
 * a uniqueness constraint, the winner's row is re-read and returned instead of the exception.
 *
 * <p>Why this is a separate bean from {@link IdempotentWriter} rather than another method on it:
 * the insert must run in its own REQUIRES_NEW transaction, and Spring applies @Transactional
 * through a proxy. A self-invocation ({@code this.insert(...)}) bypasses that proxy, so the
 * annotation would be silently ignored, the insert would join the caller's transaction, and the
 * recovery below could never work — which is precisely the bug this class exists to fix. Calling
 * across beans keeps the proxy in the path. See docs/design/2026-07-17-sync-design.md §8.
 */
@Component
public class IdempotentSaver {

    private final IdempotentWriter writer;

    public IdempotentSaver(IdempotentWriter writer) {
        this.writer = writer;
    }

    /**
     * @param finder re-reads the entity by its idempotency key. Must return Optional.empty() when
     *               the caller has no key, so an unrelated constraint violation still propagates.
     * @throws DataIntegrityViolationException if the violation was not a lost idempotency race
     */
    public <T> T saveOrGetExisting(JpaRepository<T, ?> repo, Supplier<Optional<T>> finder, T entity) {
        try {
            return writer.insert(repo, entity);
        } catch (DataIntegrityViolationException e) {
            // Lost the race: the winner's row is committed and visible now. If it is not, some
            // other constraint rejected this insert and must not be swallowed as an idempotent hit.
            return finder.get().orElseThrow(() -> e);
        }
    }
}
