#!/usr/bin/env bash
# Client of the per-environment web deploy account (deploy/web/, AI-Gov-Layer PD-44/PD-45), behind
# `make web-deploy`, `make web-rollback` and `make web-status`.
# Usage: web-remote.sh deploy <env> <artifact.tar> <sha256:digest> <backend url> | rollback <env> | status <env>
# The private key comes from WEB_DEPLOY_KEY (an environment secret in CI). The host key is pinned in
# deploy/web/known_hosts under the alias web-deploy-<env>. Prints the digest now served on stdout.
set -euo pipefail
cd "$(dirname "$0")/.."
action=${1:?usage: web-remote.sh deploy|rollback|status <env> ...}
env=${2:-}
[[ $env =~ ^[a-z0-9-]+$ ]] || { echo "ENV= must name the environment (preview, staging, production)" >&2; exit 2; }
host=${WEB_DEPLOY_HOST:-parcel-$env-web-deploy-1}
port=${WEB_DEPLOY_PORT:-2222}
known=${WEB_DEPLOY_KNOWN_HOSTS_FILE:-deploy/web/known_hosts}
grep -q "^web-deploy-$env " "$known" 2>/dev/null || { echo "no pinned host key for web-deploy-$env in $known" >&2; exit 2; }
[ -n "${WEB_DEPLOY_KEY:-}" ] || { echo "WEB_DEPLOY_KEY is not set (environment secret)" >&2; exit 2; }
key=$(mktemp)
trap 'rm -f "$key"' EXIT
printf '%s\n' "$WEB_DEPLOY_KEY" > "$key"
remote(){ ssh -F /dev/null -i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$known" -o HostKeyAlias="web-deploy-$env" -o ConnectTimeout=10 -p "$port" "deploy@$host" "$@"; }
case $action in
  deploy)
    artifact=${3:-} digest=${4:-} url=${5:-}
    [ -f "$artifact" ] && [ -n "$digest" ] && [ -n "$url" ] || { echo "usage: make web-deploy ENV= ARTIFACT= DIGEST= BACKEND_URL=" >&2; exit 2; }
    remote "deploy $digest $url" < "$artifact" ;;
  rollback|status) remote "$action" < /dev/null ;;
  *) echo "unknown action: $action" >&2; exit 2 ;;
esac
