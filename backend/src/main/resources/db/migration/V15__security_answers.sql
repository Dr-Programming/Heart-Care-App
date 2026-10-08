-- Forgot PIN through security questions.
--
-- A patient picks three questions from a fixed catalogue (SecurityQuestion) and answers them.
-- Answers are normalised (case, spacing) and stored only as BCrypt hashes: they have little
-- variety, so a slow hash matters if this table ever leaks.
CREATE TABLE user_security_answers (
    id           UUID PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_id  VARCHAR(40) NOT NULL,
    answer_hash  VARCHAR(255) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_security_answers_user_question UNIQUE (user_id, question_id)
);

CREATE INDEX idx_security_answers_user ON user_security_answers(user_id);

-- Recovery has its own lockout, separate from the PIN lockout: a patient who forgot the PIN has
-- often just locked it, and must still be able to recover.
ALTER TABLE users
    ADD COLUMN recovery_failed_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN recovery_locked_until    TIMESTAMPTZ;
