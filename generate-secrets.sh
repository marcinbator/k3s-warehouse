#!/usr/bin/env bash
# Generuje losowe hasla do plikow *.env czytanych przez secretGenerator w stack/ i spark/.
# Nie nadpisuje istniejacych plikow: Postgres zapisuje hasla przy pierwszej inicjalizacji.
set -euo pipefail
cd "$(dirname "$0")"

files=(stack/secrets/warehouse.env stack/secrets/ingest.env stack/secrets/bi.env spark/secrets/processing.env)
for f in "${files[@]}"; do
  if [ -e "$f" ]; then
    echo "$f juz istnieje, przerywam" >&2
    exit 1
  fi
done

rnd() { openssl rand -hex 24; }
PG_SUPER=$(rnd)
PG_SPARK=$(rnd)
PG_MB_RO=$(rnd)
PG_MB_APP=$(rnd)
S3_ROOT=$(rnd)
S3_SPARK=$(rnd)
MB_ADMIN="Mb1-$(rnd)"
MB_KEY=$(openssl rand -base64 32)

umask 077
mkdir -p stack/secrets spark/secrets

cat > stack/secrets/warehouse.env <<EOF
POSTGRES_PASSWORD=$PG_SUPER
SPARK_DB_PASSWORD=$PG_SPARK
METABASE_RO_PASSWORD=$PG_MB_RO
METABASE_APP_PASSWORD=$PG_MB_APP
EOF

cat > stack/secrets/ingest.env <<EOF
MINIO_ROOT_USER=minio-root
MINIO_ROOT_PASSWORD=$S3_ROOT
SPARK_S3_ACCESS_KEY=spark-etl
SPARK_S3_SECRET_KEY=$S3_SPARK
EOF

cat > stack/secrets/bi.env <<EOF
MB_ENCRYPTION_SECRET_KEY=$MB_KEY
MB_DB_PASS=$PG_MB_APP
MB_ADMIN_PASSWORD=$MB_ADMIN
WAREHOUSE_RO_PASSWORD=$PG_MB_RO
EOF

cat > spark/secrets/processing.env <<EOF
S3_ACCESS_KEY=spark-etl
S3_SECRET_KEY=$S3_SPARK
PG_PASSWORD=$PG_SPARK
EOF

echo "Wygenerowano: ${files[*]}"
