# ════════════════════════════════════════════════════════════════════════════
#  WAN — ether1 uplink, interface lists, upstream DHCP client, DNS resolver.
#  All four resources pre-exist on a fresh router as part of the factory
#  `defconf` setup and must be imported before the first apply.  See README
#  for the exact import commands.
# ════════════════════════════════════════════════════════════════════════════

# ── Interface lists ──────────────────────────────────────────────────────────
# defconf creates two named lists referenced throughout the firewall: WAN holds
# the upstream interface (ether1), LAN holds the bridge.  Membership is what
# lets a single firewall rule apply to "anything inside" or "anything outside"
# without naming individual interfaces.

resource "routeros_interface_list" "wan" {
  name    = "WAN"
  comment = "defconf"
}

resource "routeros_interface_list" "lan" {
  name    = "LAN"
  comment = "defconf"
}

resource "routeros_interface_list_member" "wan_ether1" {
  list      = routeros_interface_list.wan.name
  interface = "ether1"
  comment   = "defconf"
}

resource "routeros_interface_list_member" "lan_bridge" {
  list      = routeros_interface_list.lan.name
  interface = "bridge"
  comment   = "defconf"
}

# ── Upstream DHCP client on ether1 ───────────────────────────────────────────
# The ISP hands out an address via DHCP on the WAN port.  `use_peer_dns=true`
# means the router uses the ISP's DNS as upstream for its own resolver (which
# clients query via /ip dns below).

resource "routeros_ip_dhcp_client" "wan" {
  interface         = "ether1"
  comment           = "defconf"
  disabled          = false
  use_peer_dns      = true
  use_peer_ntp      = true
  add_default_route = "yes"
}

# ── DNS resolver ─────────────────────────────────────────────────────────────
# allow_remote_requests=true lets LAN clients use the router as their DNS
# (referenced in dhcp.tf:43).  servers stays empty — the DHCP client populates
# dynamic upstreams from the ISP.  Override here if you want a fixed resolver
# (e.g. ["1.1.1.1", "9.9.9.9"]).

resource "routeros_ip_dns" "this" {
  allow_remote_requests = true
}
