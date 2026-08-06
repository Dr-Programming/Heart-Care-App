-- Auth model change: email + password  ->  phone (+251XXXXXXXXX) + 4-digit PIN.
--
-- The app is pre-release and has no production users. Existing rows cannot be migrated
-- forward because no phone number was ever collected, and `phone` is UNIQUE NOT NULL, so
-- there is no backfill value that would satisfy the constraint. The table is therefore
-- emptied first. CASCADE clears the dependent log tables, every one of which declares
-- `user_id ... REFERENCES users(id) ON DELETE CASCADE`.
TRUNCATE TABLE users CASCADE;

ALTER TABLE users
    DROP COLUMN email,
    DROP COLUMN password_hash,
    ADD COLUMN phone                 VARCHAR(20)  NOT NULL,
    ADD COLUMN pin_hash              VARCHAR(255) NOT NULL,
    ADD COLUMN preferred_language    VARCHAR(2)   NOT NULL DEFAULT 'en',
    ADD COLUMN failed_login_attempts INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN locked_until          TIMESTAMPTZ;

ALTER TABLE users ADD CONSTRAINT users_phone_key UNIQUE (phone);
