-- Column is `vital_values` because `values` is a reserved word in PostgreSQL.
CREATE TABLE vitals_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type              VARCHAR(20) NOT NULL,
    vital_values      JSONB NOT NULL,
    flagged           BOOLEAN NOT NULL DEFAULT FALSE,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_vitals_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_vitals_user_measured ON vitals_logs(user_id, measured_at);
CREATE INDEX idx_vitals_user_type     ON vitals_logs(user_id, type);
