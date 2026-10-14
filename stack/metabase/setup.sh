#!/bin/sh
set -eu
MB=http://metabase.bi.svc.cluster.local:3000
JSON='Content-Type: application/json'

until curl -sf "$MB/api/health"; do sleep 5; done

PROPS=$(curl -sf "$MB/api/session/properties")
if echo "$PROPS" | grep -q '"has-user-setup":true'; then
  echo "Metabase juz skonfigurowany"
  exit 0
fi
TOKEN=$(echo "$PROPS" | sed -n 's/.*"setup-token":"\([^"]*\)".*/\1/p')

SESSION=$(curl -sf -X POST "$MB/api/setup" -H "$JSON" -d "{
  \"token\": \"$TOKEN\",
  \"user\": {\"first_name\": \"Admin\", \"email\": \"$MB_ADMIN_EMAIL\", \"password\": \"$MB_ADMIN_PASSWORD\"},
  \"prefs\": {\"site_name\": \"BHD Hurtownia\"}
}" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

curl -sf -X POST "$MB/api/database" -H "$JSON" -H "X-Metabase-Session: $SESSION" -d "{
  \"engine\": \"postgres\", \"name\": \"Hurtownia\",
  \"details\": {\"host\": \"$PG_HOST\", \"port\": 5432, \"dbname\": \"$PG_DB\", \"user\": \"$PG_USER\", \"password\": \"$PG_PASSWORD\"}
}"
