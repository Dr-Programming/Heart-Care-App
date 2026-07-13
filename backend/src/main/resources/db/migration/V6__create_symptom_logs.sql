-- One row per daily symptom check-in. `data` holds the patient's entered fields;
-- `assessment` holds the server-computed {overall, symptoms} severity snapshot.
CREATE TABLE symptom_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    data              JSONB NOT NULL,
    assessment        JSONB NOT NULL,
    overall_severity  VARCHAR(20) NOT NULL,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_symptom_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_symptom_user_measured ON symptom_logs(user_id, measured_at);
CREATE INDEX idx_symptom_user_severity ON symptom_logs(user_id, overall_severity);
