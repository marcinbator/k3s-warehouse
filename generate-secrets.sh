#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

files=(stack/secrets/warehouse.env stack/secrets/ingest.env stack/secrets/bi.env spark/secrets/processing.env
       stack/secrets/ca.crt stack/secrets/postgres-tls.crt stack/secrets/postgres-tls.key
       stack/secrets/minio-tls.crt stack/secrets/minio-tls.key spark/secrets/ca.crt spark/secrets/truststore.p12)
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

CA_DIR=$(mktemp -d)
trap 'rm -rf "$CA_DIR"' EXIT
ec() { openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes "$@" 2>/dev/null; }
ec -x509 -days 365 -subj /CN=k3s-warehouse-ca -keyout "$CA_DIR/ca.key" -out stack/secrets/ca.crt

cert() {
  ec -subj "/CN=$2" -keyout "stack/secrets/$1.key" -out "$CA_DIR/$1.csr"
  openssl x509 -req -in "$CA_DIR/$1.csr" -CA stack/secrets/ca.crt -CAkey "$CA_DIR/ca.key" -days 365 \
    -extfile <(printf 'subjectAltName=%s\nextendedKeyUsage=serverAuth\n' "$3") -out "stack/secrets/$1.crt" 2>/dev/null
}
cert postgres-tls postgres.warehouse.svc.cluster.local \
  DNS:postgres.warehouse.svc.cluster.local,DNS:postgres.warehouse.svc,DNS:postgres,DNS:localhost
cert minio-tls minio.ingest.svc.cluster.local \
  DNS:minio.ingest.svc.cluster.local,DNS:minio.ingest.svc,DNS:minio,DNS:localhost,IP:127.0.0.1

cp stack/secrets/ca.crt spark/secrets/ca.crt
openssl pkcs12 -export -nokeys -in stack/secrets/ca.crt -jdktrust anyExtendedKeyUsage \
  -passout pass:changeit -out spark/secrets/truststore.p12

echo "Wygenerowano: ${files[*]}"
