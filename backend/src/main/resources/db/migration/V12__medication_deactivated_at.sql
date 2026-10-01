-- When a medication was switched off (TEST_REPORT Issue 2).
--
-- Dose logs for an inactive medication are rejected only when they are scheduled AFTER the day
-- it was deactivated. The app is offline-first: a dose taken on Monday may reach the server only
-- after the medication was deactivated on Tuesday, and that is real history, not corruption.
ALTER TABLE medications ADD COLUMN deactivated_at TIMESTAMPTZ;

-- Best available estimate for medications already inactive: their last modification.
UPDATE medications SET deactivated_at = updated_at WHERE active = FALSE;
