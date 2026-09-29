-- Researcher access: accounts created and controlled by admins, who see only anonymised data.
-- Researchers are a third, separate principal type (alongside patients in `users` and admins in
-- `admin_users`); none of these tables are reachable from patient or admin sign-in.

CREATE TABLE researchers (
    id                      UUID PRIMARY KEY,
    username                VARCHAR(64)  NOT NULL,
    full_name               VARCHAR(255) NOT NULL,
    organisation            VARCHAR(255),
    password_hash           VARCHAR(255) NOT NULL,
    -- Set when an admin issues a password; cleared by the researcher's one self-service change.
    must_change_password    BOOLEAN      NOT NULL DEFAULT TRUE,
    self_changes_remaining  INTEGER      NOT NULL DEFAULT 1,
    status                  VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    -- Embedded in every researcher JWT; bumping it invalidates all tokens already issued.
    token_version           INTEGER      NOT NULL DEFAULT 0,
    created_by_admin_id     UUID         REFERENCES admin_users(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at              TIMESTAMPTZ,
    last_login_at           TIMESTAMPTZ,
    password_changed_at     TIMESTAMPTZ,
    CONSTRAINT researchers_username_key UNIQUE (username),
    CONSTRAINT researchers_status_check CHECK (status IN ('ACTIVE', 'REVOKED')),
    CONSTRAINT researchers_self_changes_check CHECK (self_changes_remaining IN (0, 1))
);

CREATE TABLE researcher_grants (
    researcher_id     UUID PRIMARY KEY REFERENCES researchers(id) ON DELETE CASCADE,
    access_level      VARCHAR(15) NOT NULL DEFAULT 'AGGREGATE',
    ds_vitals         BOOLEAN     NOT NULL DEFAULT FALSE,
    ds_symptoms       BOOLEAN     NOT NULL DEFAULT FALSE,
    ds_activity       BOOLEAN     NOT NULL DEFAULT FALSE,
    ds_medications    BOOLEAN     NOT NULL DEFAULT FALSE,
    ds_demographics   BOOLEAN     NOT NULL DEFAULT FALSE,
    export_allowed    BOOLEAN     NOT NULL DEFAULT FALSE,
    data_from         DATE,
    data_to           DATE,
    expires_at        TIMESTAMPTZ,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by        UUID        REFERENCES admin_users(id),
    CONSTRAINT researcher_grants_level_check CHECK (access_level IN ('AGGREGATE', 'PSEUDONYMOUS')),
    CONSTRAINT researcher_grants_window_check CHECK (data_from IS NULL OR data_to IS NULL OR data_from <= data_to)
);

-- Single-row settings table; the CHECK on id pins it to one row.
CREATE TABLE research_settings (
    id              INTEGER PRIMARY KEY DEFAULT 1,
    min_group_size  INTEGER NOT NULL DEFAULT 5,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT research_settings_single_row CHECK (id = 1),
    CONSTRAINT research_settings_k_check CHECK (min_group_size BETWEEN 2 AND 50)
);
INSERT INTO research_settings (id) VALUES (1);

CREATE TABLE research_cohorts (
    id             UUID PRIMARY KEY,
    researcher_id  UUID         NOT NULL REFERENCES researchers(id) ON DELETE CASCADE,
    name           VARCHAR(120) NOT NULL,
    definition     JSONB        NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_research_cohorts_researcher ON research_cohorts(researcher_id);

-- One row per researcher HTTP request, including failed sign-ins (researcher_id NULL when the
-- username matched no account). Append-only by convention: nothing in the app updates or deletes.
CREATE TABLE research_audit_log (
    id                  BIGSERIAL PRIMARY KEY,
    researcher_id       UUID REFERENCES researchers(id) ON DELETE SET NULL,
    username_attempted  VARCHAR(64),
    occurred_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    method              VARCHAR(10)  NOT NULL,
    path                VARCHAR(255) NOT NULL,
    params              JSONB,
    status              INTEGER      NOT NULL,
    rows_returned       INTEGER,
    duration_ms         INTEGER      NOT NULL,
    ip                  VARCHAR(64),
    user_agent          VARCHAR(255)
);
CREATE INDEX idx_research_audit_researcher_time ON research_audit_log(researcher_id, occurred_at DESC);
CREATE INDEX idx_research_audit_time ON research_audit_log(occurred_at DESC);

CREATE TABLE researcher_admin_events (
    id             BIGSERIAL PRIMARY KEY,
    researcher_id  UUID        NOT NULL REFERENCES researchers(id) ON DELETE CASCADE,
    admin_id       UUID        REFERENCES admin_users(id),
    action         VARCHAR(20) NOT NULL,
    details        JSONB,
    occurred_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_researcher_admin_events_researcher ON researcher_admin_events(researcher_id, occurred_at DESC);
