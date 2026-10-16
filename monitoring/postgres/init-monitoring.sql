-- Run by the postgres-monitoring-init container on every `up`; safe to re-run.
-- Invoked as: psql -v ON_ERROR_STOP=1 -v pw="$MONITORING_DB_PASSWORD" -f init-monitoring.sql
--
-- Query statistics for the System Control Centre. The library itself must be preloaded, which
-- docker-compose.monitoring.yml does via the postgres command line.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- A dedicated read-only account for postgres-exporter, so the exporter never holds the
-- application's credentials. pg_monitor grants read access to the statistics views only.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'monitoring_user') THEN
        CREATE ROLE monitoring_user LOGIN;
    END IF;
END
$$;

ALTER ROLE monitoring_user WITH LOGIN PASSWORD :'pw' CONNECTION LIMIT 5;
GRANT pg_monitor TO monitoring_user;
