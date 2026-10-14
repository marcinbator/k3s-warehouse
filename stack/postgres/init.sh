#!/bin/bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v spark_pw="$SPARK_DB_PASSWORD" \
  -v mb_ro_pw="$METABASE_RO_PASSWORD" \
  -v mb_app_pw="$METABASE_APP_PASSWORD" <<'EOSQL'
REVOKE ALL ON DATABASE warehouse FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA dwh;
CREATE TABLE dwh.sales_daily (
  order_date date,
  region     text,
  orders     bigint NOT NULL,
  units      bigint,
  revenue    double precision,
  loaded_at  timestamp NOT NULL
);

CREATE ROLE spark_etl LOGIN PASSWORD :'spark_pw';
GRANT CONNECT ON DATABASE warehouse TO spark_etl;
GRANT USAGE ON SCHEMA dwh TO spark_etl;
GRANT SELECT, INSERT, TRUNCATE ON dwh.sales_daily TO spark_etl;

CREATE ROLE metabase_ro LOGIN PASSWORD :'mb_ro_pw';
GRANT CONNECT ON DATABASE warehouse TO metabase_ro;
GRANT USAGE ON SCHEMA dwh TO metabase_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA dwh TO metabase_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA dwh GRANT SELECT ON TABLES TO metabase_ro;

CREATE ROLE metabase_app LOGIN PASSWORD :'mb_app_pw';
CREATE DATABASE metabase OWNER metabase_app;
REVOKE ALL ON DATABASE metabase FROM PUBLIC;
EOSQL
