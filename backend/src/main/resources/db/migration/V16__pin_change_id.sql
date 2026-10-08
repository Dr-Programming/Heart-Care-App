-- Safe retries for PIN changes made offline (POST /auth/pin-change, POST /auth/reset-pin).
--
-- The phone tags each change with a UUID. If the server applied a change but the phone never got
-- the answer, the retry still carries the old PIN, which no longer matches. Remembering the last
-- applied changeId lets the server recognise that retry and answer it again instead of reporting
-- a conflict.
ALTER TABLE users ADD COLUMN last_pin_change_id UUID;
