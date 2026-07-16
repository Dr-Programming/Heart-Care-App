-- One row per logged physical-activity session. `data` holds the patient's entered
-- fields (type, durationMinutes, intensity, optional steps/distanceMeters). Unlike
-- vitals/symptoms this slice computes nothing, so there is no assessment/severity column.
CREATE TABLE activity_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    data              JSONB NOT NULL,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_activity_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_activity_user_measured ON activity_logs(user_id, measured_at);
