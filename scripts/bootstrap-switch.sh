#!/usr/bin/env bash
# Bootstrap a MikroTik RB5009 as a dumb switch.
# Run once — reconfigures the management IP, removes the factory DHCP server,
# then enables the HTTPS REST API needed by OpenTofu.
#
# IMPORTANT: The switch must NOT be connected to the router's bridge during
# this step, because both devices ship with 192.168.88.1 as the default IP.
# Connect a laptop directly to one of the switch's ethernet ports instead,
# then run this script.  Reconnect the SFP+ cable to the router afterwards.
#
# Usage: bootstrap-switch.sh [INIT_HOST] [FINAL_HOST] [USER] [PASS]
#   INIT_HOST  — current IP of the device (default: 192.168.88.1, factory)
#   FINAL_HOST — desired management IP    (default: 192.168.1.2)
#   USER       — admin username           (default: admin)
#   PASS       — password (required; blank on factory-fresh devices → pass "")
set -euo pipefail

INIT_HOST="${1:-192.168.88.1}"
FINAL_HOST="${2:-192.168.1.2}"
USER="${3:-admin}"
PASS="${4-}"  # intentionally not :? — factory devices have a blank password

run_init() {
  sshpass -p "$PASS" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o ConnectTimeout=5 \
    "$USER@$INIT_HOST" "$@"
}

run_final() {
  sshpass -p "$PASS" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o ConnectTimeout=5 \
    "$USER@$FINAL_HOST" "$@"
}

echo "==> Verifying connectivity to $INIT_HOST..."
run_init "echo ok"

# ── 1. Ensure ether1 is in the bridge ────────────────────────────────────────
# Factory config uses ether1 as a WAN port (with a DHCP client) and puts
# ether2–ether8 + sfp-sfpplus1 in the bridge.  For a pure switch we want all
# nine ports in the same bridge, so add ether1 if it isn't there already.
echo "==> Adding ether1 to bridge (if not already present)..."
run_init "/ip dhcp-client remove [find where interface=ether1]" 2>/dev/null || true
run_init "/interface bridge port add interface=ether1 bridge=bridge" 2>/dev/null || true

# ── 2. Add the new management IP before removing the old one ─────────────────
echo "==> Setting management IP to $FINAL_HOST/24..."
run_init "/ip address add address=$FINAL_HOST/24 interface=bridge" 2>/dev/null || true

# ── 3. Add default route pointing to the router ──────────────────────────────
echo "==> Adding default route via 192.168.1.1..."
run_init "/ip route remove [find where dst-address=0.0.0.0/0]" 2>/dev/null || true
run_init "/ip route add dst-address=0.0.0.0/0 gateway=192.168.1.1"

# ── 4. Disable the factory DHCP server ───────────────────────────────────────
echo "==> Disabling factory DHCP server..."
run_init "/ip dhcp-server disable [find]" 2>/dev/null || true

# ── 5. Remove the old management IP ──────────────────────────────────────────
# SSH will drop after this — that is expected.
echo "==> Removing factory IP $INIT_HOST/24 (SSH will disconnect)..."
run_init "/ip address remove [find where address~\"${INIT_HOST%%/*}\"]" 2>/dev/null || true

# ── 6. Wait for the switch to answer on the new IP ───────────────────────────
echo "==> Waiting for switch to become reachable at $FINAL_HOST..."
for i in $(seq 1 30); do
  if sshpass -p "$PASS" ssh \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -o LogLevel=ERROR \
       -o ConnectTimeout=3 \
       "$USER@$FINAL_HOST" "echo ok" &>/dev/null; then
    echo "    Reachable at $FINAL_HOST"
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "ERROR — switch did not become reachable at $FINAL_HOST after 60 s." >&2
    exit 1
  fi
  echo "    Attempt $i/30 — retrying in 2 s..."
  sleep 2
done

# ── 7. Bootstrap TLS at the new IP (skip if already done) ────────────────────
if curl -fsk -u "$USER:$PASS" "https://$FINAL_HOST/rest/system/identity" > /dev/null 2>&1; then
  echo "==> HTTPS already working at $FINAL_HOST — skipping TLS bootstrap."
else
  echo "==> Running TLS bootstrap at $FINAL_HOST..."
  bash "$(dirname "$0")/bootstrap-tls.sh" "$FINAL_HOST" "$USER" "$PASS"
fi

echo ""
echo "Done. Switch is now reachable at https://$FINAL_HOST"
echo "Next steps:"
echo "  1. Run: make init-switch"
echo "  2. Import existing resources (see README for commands)"
echo "  3. Run: make plan-switch && make apply-switch"
