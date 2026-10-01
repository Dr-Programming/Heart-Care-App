-- Long-lived refresh tokens for patient sessions (TEST_REPORT Issue 6).
--
-- Only a SHA-256 of the token is stored, so a database leak does not hand out live sessions.
-- Tokens rotate on every use; all tokens descending from one sign-in share a family_id, so when a
-- token that was already rotated is presented again (a sign it was copied) the whole family is
-- revoked at once.
CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  VARCHAR(64) NOT NULL,
    family_id   UUID NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at  TIMESTAMPTZ,
    CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash)
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_family ON refresh_tokens(family_id);
