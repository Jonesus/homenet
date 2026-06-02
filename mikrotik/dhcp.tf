# ════════════════════════════════════════════════════════════════════════════
#  LAN DHCP — migrated from the factory `defconf` setup on 192.168.88.0/24 to
#  192.168.1.0/24.  The four factory resources (ip address, dhcp-server,
#  network, pool) must be imported before the first apply.  See README for the
#  exact import commands.
# ════════════════════════════════════════════════════════════════════════════

# ── DHCP address pool (dynamic range) ────────────────────────────────────────
# Mirrors the old TP-Link router's range (.100–.199) so dynamic leases stay out
# of the static-reservation band (.100–.199 happens to contain static entries
# too — that's fine, the server pins the MAC→IP mapping and the pool skips the
# reserved addresses automatically).

resource "routeros_ip_pool" "lan" {
  # Keeps the factory name to avoid a destroy/replace cycle — the pool is
  # referenced by `routeros_ip_dhcp_server.lan.address_pool` and briefly losing
  # it would take DHCP offline.
  name   = "default-dhcp"
  ranges = ["192.168.1.100-192.168.1.199"]
}

# ── DHCP server on the LAN bridge ────────────────────────────────────────────

resource "routeros_ip_dhcp_server" "lan" {
  # Factory name retained — renaming forces replacement, which would drop DHCP
  # for every client on the segment.
  name         = "defconf"
  interface    = "bridge"
  address_pool = routeros_ip_pool.lan.name
  lease_time   = "1d"
  disabled     = false
}

# ── DHCP network options announced to clients ────────────────────────────────
# Primary DNS is AdGuard Home running in the k8s cluster, exposed via MetalLB
# at a pinned LoadBalancer IP (see public/infrastructure/adguard/loadbalancer.yaml).
# AdGuard provides ad-blocking + a wildcard rewrite for *.internal → ingress IP,
# letting LAN clients reach k8s services as <svc>.internal.
#
# The router (192.168.1.1) stays as a secondary so a cluster outage does not
# take LAN DNS down — clients fall back to RouterOS's resolver.

resource "routeros_ip_dhcp_server_network" "lan" {
  address    = "192.168.1.0/24"
  gateway    = "192.168.1.1"
  dns_server = ["192.168.1.209", "192.168.1.1"]
}

# ── Static DHCP reservations ─────────────────────────────────────────────────
# Migrated verbatim from the old TP-Link Archer VR400 backup.  Last octets are
# preserved; the third octet was 1 on the old router too, so nothing else
# changes.  Comments are populated where the device identity is known.

locals {
  static_leases = {
    "A8:20:66:28:DB:4E" = { ip = "192.168.1.182", comment = "" }
    "84:CC:A8:9D:1E:DB" = { ip = "192.168.1.128", comment = "" }
    "EC:B5:FA:12:0E:E0" = { ip = "192.168.1.108", comment = "" }
    "24:62:AB:FD:13:3C" = { ip = "192.168.1.107", comment = "fornuftig-1" }
    "64:90:C1:03:44:6F" = { ip = "192.168.1.102", comment = "Roborock" }
    "B8:AE:ED:79:6B:FC" = { ip = "192.168.1.117", comment = "" }
    "00:09:B0:B7:AA:BB" = { ip = "192.168.1.116", comment = "" }
    "00:08:9B:D3:A5:79" = { ip = "192.168.1.103", comment = "" }
    "6C:C7:EC:55:D8:D8" = { ip = "192.168.1.110", comment = "" }
    "B4:60:ED:5F:E2:3A" = { ip = "192.168.1.123", comment = "" }
    "10:DD:B1:BC:CD:21" = { ip = "192.168.1.180", comment = "" }
    "0C:4D:E9:AE:78:76" = { ip = "192.168.1.181", comment = "" }
    "9C:9C:1F:CE:A2:5F" = { ip = "192.168.1.105", comment = "" }
    "78:55:36:01:11:BF" = { ip = "192.168.1.133", comment = "" }
    "78:55:36:01:11:C0" = { ip = "192.168.1.111", comment = "" }
    "70:C9:32:93:89:00" = { ip = "192.168.1.101", comment = "Valetudo" }
    "54:EF:44:9B:C6:34" = { ip = "192.168.1.109", comment = "Aqara Hub M100 (Thread Border Router)" }
    "48:26:4C:62:F1:60" = { ip = "192.168.1.120", comment = "Bosch dishwasher" }
    # Everything Presence Pro 699300 — pinned per-interface so the device gets
    # a stable IP whichever side of the `network_type` select is active. The
    # Ethernet MAC is base MAC + 3 (Espressif ESP32 MAC allocation). RouterOS
    # rejects two static leases on the same IP, so the two interfaces sit on
    # adjacent addresses; HA's ESPHome integration uses mDNS, so it
    # auto-rediscovers across a switch.
    "F4:2D:C9:69:93:00" = { ip = "192.168.1.126", comment = "Everything Presence Pro 699300 (WiFi)" }
    "F4:2D:C9:69:93:03" = { ip = "192.168.1.127", comment = "Everything Presence Pro 699300 (Ethernet)" }
  }
}

resource "routeros_ip_dhcp_server_lease" "static" {
  for_each = local.static_leases

  address     = each.value.ip
  mac_address = each.key
  server      = routeros_ip_dhcp_server.lan.name
  comment     = each.value.comment
}
