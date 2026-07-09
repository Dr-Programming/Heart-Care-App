CREATE TABLE dose_logs (
    id                UUID PRIMARY KEY,
    medication_id     UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_date    DATE NOT NULL,
    scheduled_time    TIME,
    status            VARCHAR(10) NOT NULL,
    logged_at         TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_dose_logs_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_dose_logs_user_date ON dose_logs(user_id, scheduled_date);
CREATE INDEX idx_dose_logs_medication ON dose_logs(medication_id);
