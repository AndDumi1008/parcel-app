#!/usr/bin/env bash
# Join the AGL Caddy container to this stack's network so preview-api.<domain> can reach the API over Docker DNS.
# Idempotent; run after `docker compose up -d` in this folder. Caddy's route lives in AI-Gov-Layer stack/caddy/Caddyfile.
set -euo pipefail
NET="${STACK_NAME:-parcel-preview}-net"
CADDY="${CADDY_CONTAINER:-agl-caddy-1}"
if docker network inspect "$NET" --format '{{range .Containers}}{{.Name}} {{end}}' | grep -qw "$CADDY"; then
  echo "$CADDY already on $NET"
else
  docker network connect "$NET" "$CADDY" && echo "$CADDY connected to $NET"
fi
