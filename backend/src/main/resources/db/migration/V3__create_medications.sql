CREATE TABLE medications (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name              VARCHAR(255) NOT NULL,
    dose_mg           NUMERIC(8,2) NOT NULL,
    frequency         VARCHAR(20) NOT NULL,
    schedule_times    JSONB NOT NULL DEFAULT '[]'::jsonb,
    active            BOOLEAN NOT NULL DEFAULT TRUE,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_medications_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_medications_user ON medications(user_id);
