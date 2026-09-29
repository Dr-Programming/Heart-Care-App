-- Operators of the read-only admin panel. Deliberately separate from `users`: admins are not
-- patients, never own health data, and sign in with a username + password rather than the
-- phone + PIN pair the mobile app uses. Rows are created only by AdminBootstrap from
-- ADMIN_USERNAME / ADMIN_PASSWORD — there is no registration endpoint.
CREATE TABLE admin_users (
    id             UUID PRIMARY KEY,
    username       VARCHAR(64)  NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_login_at  TIMESTAMPTZ,
    CONSTRAINT admin_users_username_key UNIQUE (username)
);
