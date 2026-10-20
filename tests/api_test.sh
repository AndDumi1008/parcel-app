#!/usr/bin/env bash
# Through-the-API check of the role views with JWTs (PostgREST switches role per token; RLS applies).
# Usage: tests/api_test.sh <api base url> <jwt secret>
set -euo pipefail
cd "$(dirname "$0")/.."
API="${1:-http://127.0.0.1:54331}"; export JWT_SECRET="${2:-${JWT_SECRET:?}}"
ok=0; bad=0
check(){ if [ "$2" = "$3" ]; then echo "  PASS $1"; ok=$((ok+1)); else echo "  FAIL $1 (expected $2, got $3)"; bad=$((bad+1)); fi; }
ANA=$(python3 scripts/jwt.py app_customer a0000000-0000-0000-0000-000000000001 customer)
LENA=$(python3 scripts/jwt.py app_courier a0000000-0000-0000-0000-000000000004 courier)
SORT=$(python3 scripts/jwt.py app_sorter a0000000-0000-0000-0000-000000000005 sorter)
SUPP=$(python3 scripts/jwt.py app_support a0000000-0000-0000-0000-000000000006 support)
ANAL=$(python3 scripts/jwt.py app_analyst a0000000-0000-0000-0000-000000000007 analyst)
q(){ curl -sS -m 10 -H "Authorization: Bearer $1" "$API/$2"; }
code(){ if [ -n "$1" ]; then curl -sS -m 10 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $1" "$API/$2"; else curl -sS -m 10 -o /dev/null -w '%{http_code}' "$API/$2"; fi; }
count(){ python3 -c 'import sys,json;d=json.load(sys.stdin);print(len(d) if isinstance(d,list) else "err")'; }
check "anon sees no table"              "401" "$(code '' parcel)"
check "customer: one tracking row"      "1"   "$(q "$ANA" customer_tracking_v | count)"
check "customer: parcel ref"            "RO-CJ-2026-0048213" "$(q "$ANA" 'customer_tracking_v?select=ref' | python3 -c 'import sys,json;print(json.load(sys.stdin)[0]["ref"])')"
check "customer cannot read stop table" "401" "$(code "$ANA" stop)"
check "courier: one open stop"          "1"   "$(q "$LENA" courier_stop_v | count)"
check "courier: one party only"         "1"   "$(q "$LENA" party | count)"
check "sorter: party forbidden"         "401" "$(code "$SORT" party)"
check "sorter: routing visible"         "2"   "$(q "$SORT" sorter_parcel_v | count)"
check "support: phone masked"           "yes" "$(q "$SUPP" 'support_parcel_v?select=sender_phone' | python3 -c 'import sys,json;print("yes" if all("••" in (r["sender_phone"] or "") for r in json.load(sys.stdin)) else "no")')"
check "support: party forbidden"        "401" "$(code "$SUPP" party)"
check "analyst: pseudonyms only"        "yes" "$(q "$ANAL" 'analytics_parcel_v?select=sender_pseudonym' | python3 -c 'import sys,json;print("yes" if all(r["sender_pseudonym"].startswith("snd_") for r in json.load(sys.stdin)) else "no")')"
echo "== $ok passed, $bad failed"; [ $bad -eq 0 ]
