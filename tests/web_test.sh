#!/usr/bin/env bash
# Web hosting end to end (AI-Gov-Layer PD-44/PD-45): a throw-away web + web-deploy pair from the stack's compose
# file, the client behind `make web-deploy` / `web-rollback` / `web-status`, two placeholder releases, a rollback,
# and the refusals the forced command must give. Needs docker, ssh, curl and python3.
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT=parcel-webtest
WEB=http://127.0.0.1:18080
T=$(mktemp -d)
ssh-keygen -q -t ed25519 -N '' -C web-test -f "$T/key"
ssh-keygen -q -t ed25519 -N '' -C web-test-other -f "$T/other"
cat > "$T/env" <<EOF
STACK_NAME=$PROJECT
WEB_DEPLOY_PUBKEY=$(cat "$T/key.pub")
POSTGRES_PASSWORD=unused
AUTHENTICATOR_PASSWORD=unused
JWT_SECRET=unused
EOF
DC="docker compose -p $PROJECT --env-file $T/env -f deploy/preview/docker-compose.yml -f tests/web.compose.yml"
cleanup(){ $DC down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$T" out; }
trap cleanup EXIT

$DC up -d --build web web-deploy >/dev/null
for _ in $(seq 1 30); do $DC logs web-deploy 2>/dev/null | grep -q 'Server listening' && break; sleep 1; done
echo "web-deploy-test $($DC exec -T web-deploy cut -d' ' -f1,2 /keys/ssh_host_ed25519_key.pub)" > "$T/known_hosts"

export WEB_DEPLOY_KEY WEB_DEPLOY_HOST=127.0.0.1 WEB_DEPLOY_PORT=12222 WEB_DEPLOY_KNOWN_HOSTS_FILE="$T/known_hosts"
WEB_DEPLOY_KEY=$(cat "$T/key")
ok=0; bad=0
check(){ if [ "$2" = "$3" ]; then echo "  PASS $1"; ok=$((ok+1)); else echo "  FAIL $1 (expected $2, got $3)"; bad=$((bad+1)); fi; }
sha256(){ if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }
pack(){ COPYFILE_DISABLE=1 tar --format=ustar -C "$1" -cf "$2" .; echo "sha256:$(sha256 "$2")"; }
# evil <tar> <kind>: an otherwise valid release with one bad member, built with python so it is the same on any OS
evil(){ python3 - "$1" "$2" <<'PY'
import io, sys, tarfile
path, kind = sys.argv[1], sys.argv[2]
with tarfile.open(path, "w", format=tarfile.USTAR_FORMAT) as t:
    def add(name, data=b"x", **kw):
        i = tarfile.TarInfo(name); i.size = len(data); [setattr(i, k, v) for k, v in kw.items()]
        t.addfile(i, io.BytesIO(data) if i.isreg() else None)
    add("./index.html", b'<html data-app="parcel">evil</html>')
    if kind == "symlink":  add("./passwd", b"", type=tarfile.SYMTYPE, linkname="/etc/passwd")
    if kind == "hardlink": add("./passwd", b"", type=tarfile.LNKTYPE, linkname="../../etc/passwd")
    if kind == "dotdot":   add("../escape.txt")
    if kind == "absolute": add("/tmp/escape.txt")
PY
echo "sha256:$(sha256 "$1")"; }
deploy(){ make -s web-deploy ENV=test ARTIFACT="$1" DIGEST="$2" BACKEND_URL="${3:-https://preview-api.example.test}" 2>/dev/null; }
refused(){ if "$@" >/dev/null 2>&1; then echo accepted; else echo refused; fi; }
remote(){ ssh -F /dev/null -i "$T/key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$T/known_hosts" -o HostKeyAlias=web-deploy-test -p 12222 "$@" deploy@127.0.0.1; }
body(){ curl -sS -m 10 "$WEB$1"; }
code(){ curl -sS -m 10 -o /dev/null -w '%{http_code}' "$WEB$1"; }

make -s web-build
D1=$(pack out "$T/r1.tar")
cp -R out "$T/v2" && echo v2 > "$T/v2/version.txt"
D2=$(pack "$T/v2" "$T/r2.tar")

check "nothing deployed yet"                 "refused" "$(refused make -s web-status ENV=test)"
check "deploy r1 prints its digest"          "$D1"     "$(deploy "$T/r1.tar" "$D1")"
check "web serves the placeholder"           "yes"     "$(body / | grep -q 'data-app="parcel"' && echo yes || echo no)"
check "config.json carries the backend URL"  "https://preview-api.example.test" "$(body /config.json | python3 -c 'import sys,json;print(json.load(sys.stdin)["backendUrl"])')"
check "status shows r1"                      "$D1"     "$(make -s web-status ENV=test)"
check "deploy r2 prints its digest"          "$D2"     "$(deploy "$T/r2.tar" "$D2")"
check "web serves r2"                        "v2"      "$(body /version.txt)"
check "rollback returns to r1"               "$D1"     "$(make -s web-rollback ENV=test)"
check "web serves r1 again"                  "404"     "$(code /version.txt)"
check "redeploy of a known digest"           "$D2"     "$(deploy "$T/r2.tar" "$D2")"
check "wrong digest refused"                 "refused" "$(refused deploy "$T/r1.tar" "$D2")"
check "malformed digest refused"             "refused" "$(refused deploy "$T/r1.tar" "${D1#sha256:}")"
check "http backend URL refused"             "refused" "$(refused deploy "$T/r1.tar" "$D1" http://preview-api.example.test)"
check "backend URL with a path refused"      "refused" "$(refused deploy "$T/r1.tar" "$D1" 'https://a.example.test/"x')"
for kind in symlink hardlink dotdot absolute; do
  DE=$(evil "$T/$kind.tar" "$kind")
  check "artifact with a $kind member refused" "refused" "$(refused deploy "$T/$kind.tar" "$DE")"
done
mkdir "$T/noindex" && echo x > "$T/noindex/a.txt"; DN=$(pack "$T/noindex" "$T/noindex.tar")
check "artifact without index.html refused"  "refused" "$(refused deploy "$T/noindex.tar" "$DN")"
check "no release dir left by refusals"      "2"       "$($DC exec -T web-deploy sh -c 'ls /srv/releases | wc -l' | tr -d ' ')"
check "nothing left in incoming"             "0"       "$($DC exec -T web-deploy sh -c 'ls -A /srv/incoming | wc -l' | tr -d ' ')"
check "status still r2 after refusals"       "$D2"     "$(make -s web-status ENV=test)"
check "other commands refused"               "refused" "$(refused remote 'cat /etc/passwd' </dev/null)"
check "interactive shell refused"            "refused" "$(refused remote -tt </dev/null)"
check "port forwarding refused"              "refused" "$(refused remote -o ExitOnForwardFailure=yes -R 127.0.0.1:18999:127.0.0.1:80 status </dev/null)"
check "a different key is refused"           "refused" "$(refused env WEB_DEPLOY_KEY="$(cat "$T/other")" make -s web-status ENV=test)"
check "unpinned environment refused"         "refused" "$(refused make -s web-status ENV=staging)"
check "web container cannot write its volume" "refused" "$(refused $DC exec -T web touch /srv/current/x)"
echo "== $ok passed, $bad failed"; [ $bad -eq 0 ]
