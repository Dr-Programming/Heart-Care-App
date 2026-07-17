package com.heartcare.sync;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.sync.SyncHandler;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.sync.dto.SyncRecord;
import com.heartcare.sync.dto.SyncRequest;
import com.heartcare.sync.dto.SyncResponse;
import com.heartcare.sync.dto.SyncResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.IntStream;

/**
 * Fans a batch of offline-created records out to the feature that owns each entity type.
 *
 * <p>Imports no feature package: dispatch goes through SyncHandler, which Spring populates from
 * every feature's own handler bean (architectural rule 1).
 *
 * <p>Deliberately NOT @Transactional. Each handler call crosses into a feature service that is,
 * so every record commits or rolls back alone — one bad record must never block its neighbours
 * (design §7, Decision 4).
 */
@Service
public class SyncService {

    private static final String MEDICATION = "MEDICATION";

    private final Map<String, SyncHandler> handlers;
    private final int maxBatchSize;

    public SyncService(List<SyncHandler> handlerBeans,
                       @Value("${app.sync.max-batch-size}") int maxBatchSize) {
        Map<String, SyncHandler> byType = new HashMap<>();
        for (SyncHandler handler : handlerBeans) {
            SyncHandler previous = byType.put(handler.entityType(), handler);
            if (previous != null) {
                throw new IllegalStateException("duplicate SyncHandler for entityType " + handler.entityType()
                        + ": " + previous.getClass().getName() + " and " + handler.getClass().getName());
            }
        }
        this.handlers = Map.copyOf(byType);
        this.maxBatchSize = maxBatchSize;
    }

    public SyncResponse sync(UUID userId, SyncRequest request) {
        List<SyncRecord> records = request.records();
        if (records.size() > maxBatchSize) {
            throw new BadRequestException(
                    "batch too large: " + records.size() + " records, max is " + maxBatchSize);
        }
        SyncResult[] results = new SyncResult[records.size()];
        for (int index : processingOrder(records)) {
            results[index] = process(userId, records.get(index));
        }
        return new SyncResponse(List.of(results));
    }

    /**
     * Record indices, MEDICATION first. A dose log may name a medication created in the same
     * batch by client_record_id, so the medication must exist before the dose resolves it
     * (design Decision 8). Sort is stable, so request order holds within a rank.
     */
    private List<Integer> processingOrder(List<SyncRecord> records) {
        return IntStream.range(0, records.size()).boxed()
                .sorted(Comparator.comparingInt(i -> MEDICATION.equals(records.get(i).entityType()) ? 0 : 1))
                .toList();
    }

    private SyncResult process(UUID userId, SyncRecord record) {
        SyncHandler handler = handlers.get(record.entityType());
        if (handler == null) {
            return SyncResult.rejected(record.clientRecordId(), "unknown entityType: " + record.entityType());
        }
        try {
            SyncOutcome outcome = handler.handle(userId, record.clientRecordId(), record.payload());
            return SyncResult.of(record.clientRecordId(), outcome);
        } catch (BadRequestException | ResourceNotFoundException e) {
            // Permanent: this record can never succeed, so the client must stop retrying it.
            return SyncResult.rejected(record.clientRecordId(), e.getMessage());
        }
        // Anything else propagates on purpose. A transient fault (DB down) must fail the whole
        // batch with a 500 so the client retries; reporting REJECTED would make a correct client
        // discard unsynced health data. Retrying is safe: committed records return DUPLICATE.
    }
}
