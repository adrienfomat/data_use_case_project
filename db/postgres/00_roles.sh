#!/usr/bin/env bash
# Runs once, on first start of the postgres container (docker-entrypoint-initdb.d).
# One login role per service; passwords come from .env, never from the repo.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-SQL
  CREATE ROLE orders_svc    LOGIN PASSWORD '${ORDERS_DB_PASSWORD}';
  CREATE ROLE inventory_svc LOGIN PASSWORD '${INVENTORY_DB_PASSWORD}';
  CREATE ROLE payments_svc  LOGIN PASSWORD '${PAYMENTS_DB_PASSWORD}';
  CREATE ROLE auth_svc      LOGIN PASSWORD '${AUTH_DB_PASSWORD}';

  -- Nobody gets anything by default: least privilege.
  REVOKE ALL ON DATABASE ${POSTGRES_DB} FROM PUBLIC;
  REVOKE CREATE ON SCHEMA public FROM PUBLIC;
  GRANT CONNECT ON DATABASE ${POSTGRES_DB}
    TO orders_svc, inventory_svc, payments_svc, auth_svc;

  -- Each schema is owned by its service role: a service cannot see another's tables.
  CREATE SCHEMA orders    AUTHORIZATION orders_svc;
  CREATE SCHEMA inventory AUTHORIZATION inventory_svc;
  CREATE SCHEMA payments  AUTHORIZATION payments_svc;
  CREATE SCHEMA auth      AUTHORIZATION auth_svc;
SQL
