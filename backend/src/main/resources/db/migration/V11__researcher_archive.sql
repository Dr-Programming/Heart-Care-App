-- "Deleting" a researcher archives them: the row stays so the audit log keeps its subject, but the
-- account leaves the admin's working list, can do nothing, and its username stays reserved.
ALTER TABLE researchers DROP CONSTRAINT researchers_status_check;
ALTER TABLE researchers ADD CONSTRAINT researchers_status_check
    CHECK (status IN ('ACTIVE', 'REVOKED', 'ARCHIVED'));

ALTER TABLE researchers
    ADD COLUMN archived_at     TIMESTAMPTZ,
    ADD COLUMN archived_by     UUID REFERENCES admin_users(id),
    ADD COLUMN archive_reason  VARCHAR(500);
