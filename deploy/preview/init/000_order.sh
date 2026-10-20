#!/bin/bash
# The postgres entrypoint runs files in docker-entrypoint-initdb.d in name order but does NOT descend into
# subdirectories. This script runs first and applies migrations, seed, masking and init scripts in order.
set -euo pipefail
cd /docker-entrypoint-initdb.d
for f in 010/*.sql 015/*.sql; do echo "applying $f"; psql -v ON_ERROR_STOP=1 -U postgres -d postgres -q -f "$f"; done
if [ "${MASK_DATA:-true}" = "true" ] && [ -f 020/mask.sql ]; then echo "masking"; psql -v ON_ERROR_STOP=1 -U postgres -d postgres -q -f 020/mask.sql; fi
for f in 020/*.sh; do [ "$(basename "$f")" = "000_order.sh" ] && continue; echo "running $f"; bash "$f"; done
