#!/bin/bash
# Runs once at database initialisation after the SQL files: sets the API role password from the environment.
set -euo pipefail
: "${AUTHENTICATOR_PASSWORD:?set in .env}"
psql -v ON_ERROR_STOP=1 -U postgres -d postgres -c "alter role authenticator password '$(printf %s "$AUTHENTICATOR_PASSWORD" | sed "s/'/''/g")';"
echo "authenticator password set"
