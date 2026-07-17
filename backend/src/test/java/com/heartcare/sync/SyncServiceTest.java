package com.heartcare.sync;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.sync.SyncHandler;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.common.sync.SyncStatus;
import com.heartcare.sync.dto.SyncRecord;
import com.heartcare.sync.dto.SyncRequest;
import com.heartcare.sync.dto.SyncResponse;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SyncServiceTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final UUID userId = UUID.randomUUID();
    private final List<String> callLog = new ArrayList<>();

    /** A handler with no feature dependencies — SyncService must need nothing more. */
    private SyncHandler handler(String type, Function<UUID, SyncOutcome> behaviour) {
        return new SyncHandler() {
            @Override public String entityType() { return type; }
            @Override public SyncOutcome handle(UUID uid, UUID clientRecordId, JsonNode payload) {
                callLog.add(type);
                return behaviour.apply(clientRecordId);
            }
        };
    }

    private SyncHandler ok(String type) {
        return handler(type, crid -> SyncOutcome.saved("server-" + crid));
    }

    private SyncRecord record(String type, UUID crid) {
        return new SyncRecord(crid, type, MAPPER.createObjectNode());
    }

    @Test
    void dispatchesEachEntityTypeToItsHandler() {
        SyncService service = new SyncService(List.of(ok("VITAL"), ok("ACTIVITY")));
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();

        SyncResponse response = service.sync(userId,
                new SyncRequest(List.of(record("VITAL", a), record("ACTIVITY", b))));

        assertThat(response.results()).extracting("clientRecordId").containsExactly(a, b);
        assertThat(response.results()).extracting("status")
                .containsExactly(SyncStatus.SAVED, SyncStatus.SAVED);
        assertThat(response.results().get(0).serverId()).isEqualTo("server-" + a);
    }

    @Test
    void unknownEntityTypeIsRejectedAndBatchContinues() {
        SyncService service = new SyncService(List.of(ok("VITAL")));
        UUID bad = UUID.randomUUID();
        UUID good = UUID.randomUUID();

        SyncResponse response = service.sync(userId,
                new SyncRequest(List.of(record("FOO", bad), record("VITAL", good))));

        assertThat(response.results().get(0).status()).isEqualTo(SyncStatus.REJECTED);
        assertThat(response.results().get(0).reason()).contains("unknown entityType: FOO");
        assertThat(response.results().get(1).status()).isEqualTo(SyncStatus.SAVED);
    }

    @Test
    void badRequestBecomesRejectedWithMessageAsReason() {
        SyncService service = new SyncService(List.of(
                handler("VITAL", crid -> { throw new BadRequestException("systolic is out of range"); })));

        SyncResponse response = service.sync(userId,
                new SyncRequest(List.of(record("VITAL", UUID.randomUUID()))));

        assertThat(response.results().get(0).status()).isEqualTo(SyncStatus.REJECTED);
        assertThat(response.results().get(0).reason()).isEqualTo("systolic is out of range");
        assertThat(response.results().get(0).serverId()).isNull();
    }

    @Test
    void resourceNotFoundBecomesRejected() {
        SyncService service = new SyncService(List.of(
                handler("DOSE_LOG", crid -> { throw new ResourceNotFoundException("Medication not found"); })));

        SyncResponse response = service.sync(userId,
                new SyncRequest(List.of(record("DOSE_LOG", UUID.randomUUID()))));

        assertThat(response.results().get(0).status()).isEqualTo(SyncStatus.REJECTED);
        assertThat(response.results().get(0).reason()).isEqualTo("Medication not found");
    }

    /**
     * A transient failure must NOT become REJECTED: a client treating REJECTED as permanent
     * would delete unsynced health data over a database outage (design §7).
     */
    @Test
    void unexpectedExceptionPropagatesAndFailsTheBatch() {
        SyncService service = new SyncService(List.of(
                handler("VITAL", crid -> { throw new IllegalStateException("connection pool exhausted"); })));

        assertThatThrownBy(() -> service.sync(userId,
                new SyncRequest(List.of(record("VITAL", UUID.randomUUID())))))
                .isInstanceOf(IllegalStateException.class);
    }

    /** Decision 8: a dose log must be able to resolve a medication created in the same batch. */
    @Test
    void medicationsAreProcessedBeforeDoseLogs() {
        SyncService service = new SyncService(List.of(ok("MEDICATION"), ok("DOSE_LOG")));

        service.sync(userId, new SyncRequest(List.of(
                record("DOSE_LOG", UUID.randomUUID()),
                record("MEDICATION", UUID.randomUUID()))));

        assertThat(callLog).containsExactly("MEDICATION", "DOSE_LOG");
    }

    @Test
    void resultsPreserveRequestOrderEvenWhenProcessingOrderDiffers() {
        SyncService service = new SyncService(List.of(ok("MEDICATION"), ok("DOSE_LOG")));
        UUID dose = UUID.randomUUID();
        UUID med = UUID.randomUUID();

        SyncResponse response = service.sync(userId, new SyncRequest(List.of(
                record("DOSE_LOG", dose), record("MEDICATION", med))));

        assertThat(response.results()).extracting("clientRecordId").containsExactly(dose, med);
    }

    @Test
    void duplicateEntityTypeRegistrationFailsFast() {
        assertThatThrownBy(() -> new SyncService(List.of(ok("VITAL"), ok("VITAL"))))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("VITAL");
    }
}
