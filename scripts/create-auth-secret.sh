#!/bin/bash
# ==========================================
# Create / rotate the auth-proxy Basic Auth secret
# ==========================================
# Generates an htpasswd line (SHA-512-crypt) for the given username/password,
# then writes it into a Kubernetes Secret named `auth-proxy-htpasswd` in the
# `monitoring` namespace.
#
# The nginx auth-proxy (kubernetes/auth-proxy-deployment.yml) mounts this
# Secret at /etc/nginx/auth/htpasswd.
#
# Usage:
#   bash scripts/create-auth-secret.sh <username> <password>
#
# Example:
#   bash scripts/create-auth-secret.sh monitoring 'P4ssw0rd!verylong'
#
# Rotation: run again with a new password, then:
#   kubectl -n monitoring rollout restart deploy/auth-proxy
# and update AUTH_USERNAME / AUTH_PASSWORD in every remote /etc/monitoring-agent/.env
# (then `systemctl restart promtail prom-agent` on each remote).

set -euo pipefail

USERNAME="${1:-}"
PASSWORD="${2:-}"

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
    echo "usage: $0 <username> <password>"
    exit 1
fi

if ! command -v openssl >/dev/null; then
    echo "ERROR: openssl is required to hash the password"
    exit 1
fi

if ! command -v kubectl >/dev/null; then
    echo "ERROR: kubectl is required to create the Secret"
    exit 1
fi

# SHA-512-crypt — supported by nginx auth_basic and widely available
HASH=$(openssl passwd -6 "$PASSWORD")
HTPASSWD_LINE="${USERNAME}:${HASH}"

echo "Creating Secret 'auth-proxy-htpasswd' in namespace 'monitoring'..."
kubectl -n monitoring create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
kubectl -n monitoring delete secret auth-proxy-htpasswd --ignore-not-found
kubectl -n monitoring create secret generic auth-proxy-htpasswd \
    --from-literal=htpasswd="$HTPASSWD_LINE"

echo ""
echo "Done. To roll the auth-proxy and pick up the new credentials:"
echo "  kubectl -n monitoring rollout restart deploy/auth-proxy"
echo ""
echo "Remote agents must use:"
echo "  AUTH_USERNAME=${USERNAME}"
echo "  AUTH_PASSWORD=<the password you just set>"
echo "in /etc/monitoring-agent/.env  (then systemctl restart promtail prom-agent)"
