-- One symptom check-in per patient per calendar day (TEST_REPORT Issue 3).
--
-- "Day" is the patient's local day, not the UTC day: an Ethiopian check-in at 01:00 belongs to
-- that date, not the previous one. The app sends its zone in X-Timezone and the service stores
-- the resulting local date; existing rows predate that header, so they are backfilled in the
-- deployment's default zone (app.time.default-zone).
ALTER TABLE symptom_logs ADD COLUMN check_in_date DATE;

UPDATE symptom_logs
   SET check_in_date = (measured_at AT TIME ZONE 'Africa/Addis_Ababa')::date;

-- Same-day duplicates already in the table would block the constraint below. Keep the most
-- recent check-in of each day (the patient's latest answer) and drop the rest. Pre-release data
-- only; agreed before this migration was written.
DELETE FROM symptom_logs
 WHERE id IN (
     SELECT id FROM (
         SELECT id,
                ROW_NUMBER() OVER (PARTITION BY user_id, check_in_date
                                   ORDER BY measured_at DESC, created_at DESC) AS rn
           FROM symptom_logs
     ) ranked
     WHERE ranked.rn > 1
 );

ALTER TABLE symptom_logs ALTER COLUMN check_in_date SET NOT NULL;
ALTER TABLE symptom_logs
    ADD CONSTRAINT uq_symptom_user_check_in_date UNIQUE (user_id, check_in_date);
