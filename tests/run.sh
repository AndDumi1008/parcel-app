#!/usr/bin/env bash
# Load migrations + seed into a throw-away PostgreSQL 16 and run the RLS assertions; then mask and re-check.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=parcel-rls-test
docker rm -f $NAME >/dev/null 2>&1 || true
docker run -d --name $NAME -e POSTGRES_PASSWORD=x -p 55433:5432 postgres:16 >/dev/null
trap 'docker rm -f $NAME >/dev/null 2>&1' EXIT
for i in $(seq 1 30); do docker exec $NAME pg_isready -U postgres >/dev/null 2>&1 && break; sleep 1; done
P="docker exec -i $NAME psql -U postgres -v ON_ERROR_STOP=1 -q"
for f in supabase/migrations/*.sql supabase/seed/*.sql; do $P < "$f"; echo "loaded $f"; done
docker exec -i $NAME psql -U postgres -v ON_ERROR_STOP=1 -tA < tests/rls_test.sql | grep -E "passed|FAILED" || { echo "RLS test did not report a result"; exit 1; }
$P < scripts/mask.sql && echo "masked"
docker exec -i $NAME psql -U postgres -tAc "select name, phone, email from party limit 2; select count(*) from party where email like '%example.ro' or email like '%example.de';"
