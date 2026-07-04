CREATE TABLE patient_profiles (
    user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    birth_year         INTEGER,
    preferred_language VARCHAR(5),
    height_cm          INTEGER,
    chd_stage          VARCHAR(50),
    disease_history    TEXT,
    comorbidities      JSONB NOT NULL DEFAULT '[]'::jsonb,
    management_plan    TEXT,
    goals              JSONB,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
