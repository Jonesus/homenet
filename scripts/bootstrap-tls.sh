#!/usr/bin/env bash
# Bootstrap TLS on a MikroTik router.
# Run once per device — enables the HTTPS REST API needed by OpenTofu.
#
# Usage: bootstrap-tls.sh [HOST] [USER] [PASS]
#   HOST defaults to 192.168.88.1
#   USER defaults to admin
#   PASS is required (no default)
set -euo pipefail

HOST="${1:-192.168.88.1}"
USER="${2:-admin}"
PASS="${3:?Error: password is required as 3rd argument}"

run() {
  sshpass -p "$PASS" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "$USER@$HOST" "$@"
}

echo "==> Creating self-signed CA certificate..."
run "/certificate add name=local-ca common-name=homenet-ca key-usage=key-cert-sign,crl-sign"

echo "==> Signing CA certificate..."
run "/certificate sign local-ca"

echo "==> Creating server certificate..."
run "/certificate add name=router-https common-name=$HOST"

echo "==> Signing server certificate..."
run "/certificate sign router-https ca=local-ca"

# RouterOS signs certificates asynchronously — wait for it to complete
echo "==> Waiting for signing to complete..."
sleep 5

echo "==> Assigning certificate to www-ssl and enabling HTTPS..."
run "/ip service set www-ssl certificate=router-https disabled=no"

echo "==> Verifying HTTPS connectivity..."
if curl -fsk -u "$USER:$PASS" "https://$HOST/rest/system/identity" > /dev/null; then
  echo "OK — HTTPS REST API is working on https://$HOST"
else
  echo "ERROR — HTTPS check failed. Check router logs." >&2
  exit 1
fi
