package com.heartcare.common.sync;

/** The verdict for one synced record, as reported back to the client. */
public enum SyncStatus {
    /** New record committed. */
    SAVED,
    /** client_record_id already stored and the payload matches. */
    DUPLICATE,
    /** client_record_id already stored but the payload differs — the stored record wins (design §2, Decision 3). */
    CONFLICT,
    /** Payload is invalid and will never succeed; the client must not retry it. */
    REJECTED
}
