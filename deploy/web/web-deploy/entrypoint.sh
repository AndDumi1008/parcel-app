#!/bin/sh
# Start sshd for the web deploy account. The host key persists in the keys volume; the single authorised
# public key comes from WEB_DEPLOY_PUBKEY (the public half of this environment's WEB_DEPLOY_KEY secret).
set -eu
key=${WEB_DEPLOY_PUBKEY:-}
case $key in
  ssh-ed25519\ *) ;;
  *) echo "WEB_DEPLOY_PUBKEY must be one ssh-ed25519 public key" >&2; exit 1 ;;
esac
[ "$(printf '%s' "$key" | wc -l)" -eq 0 ] || { echo "WEB_DEPLOY_PUBKEY must be a single line" >&2; exit 1; }
[ -f /keys/ssh_host_ed25519_key ] || ssh-keygen -q -t ed25519 -N '' -C '' -f /keys/ssh_host_ed25519_key
printf 'restrict %s\n' "$key" > /etc/ssh/authorized_keys
chmod 644 /etc/ssh/authorized_keys
chown deploy:deploy /srv
echo "host key line for parcel-app deploy/web/known_hosts:"
echo "web-deploy-${STACK_NAME#parcel-} $(cut -d' ' -f1,2 /keys/ssh_host_ed25519_key.pub)"
exec /usr/sbin/sshd -D -e
