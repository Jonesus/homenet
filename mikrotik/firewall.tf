# ════════════════════════════════════════════════════════════════════════════
#  Firewall — defconf filter rules, srcnat masquerade, and inbound dst-nat for
#  the Kubernetes ingress (HTTP/HTTPS).
#
#  All rules in the `defconf_*` and `masquerade` resources pre-exist as part of
#  the factory configuration and must be imported before the first apply.  The
#  `dstnat_k8s_*` rules are net-new and will be created on apply.
#
#  Rule order within each chain matters in RouterOS — terraform-routeros sets
#  position via the order of resources in state.  Do not reorder these blocks
#  without re-importing.
# ════════════════════════════════════════════════════════════════════════════

# ── Filter: input chain (traffic destined for the router itself) ─────────────

resource "routeros_ip_firewall_filter" "defconf_input_established" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established,related,untracked"
}

resource "routeros_ip_firewall_filter" "defconf_input_drop_invalid" {
  chain            = "input"
  action           = "drop"
  connection_state = "invalid"
  comment          = "defconf: drop invalid"
}

resource "routeros_ip_firewall_filter" "defconf_input_icmp" {
  chain    = "input"
  action   = "accept"
  protocol = "icmp"
  comment  = "defconf: accept ICMP"
}

resource "routeros_ip_firewall_filter" "defconf_input_loopback" {
  chain       = "input"
  action      = "accept"
  dst_address = "127.0.0.1"
  comment     = "defconf: accept to local loopback (for CAPsMAN)"
}

resource "routeros_ip_firewall_filter" "defconf_input_drop_nonlan" {
  chain             = "input"
  action            = "drop"
  in_interface_list = "!LAN"
  comment           = "defconf: drop all not coming from LAN"
}

# ── Filter: forward chain (traffic transiting the router) ────────────────────

resource "routeros_ip_firewall_filter" "defconf_forward_ipsec_in" {
  chain        = "forward"
  action       = "accept"
  ipsec_policy = "in,ipsec"
  comment      = "defconf: accept in ipsec policy"
}

resource "routeros_ip_firewall_filter" "defconf_forward_ipsec_out" {
  chain        = "forward"
  action       = "accept"
  ipsec_policy = "out,ipsec"
  comment      = "defconf: accept out ipsec policy"
}

resource "routeros_ip_firewall_filter" "defconf_forward_fasttrack" {
  chain            = "forward"
  action           = "fasttrack-connection"
  connection_state = "established,related"
  hw_offload       = true
  comment          = "defconf: fasttrack"
}

resource "routeros_ip_firewall_filter" "defconf_forward_established" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established,related, untracked"
}

resource "routeros_ip_firewall_filter" "defconf_forward_drop_invalid" {
  chain            = "forward"
  action           = "drop"
  connection_state = "invalid"
  comment          = "defconf: drop invalid"
}

# This is the rule that makes dst-nat necessary for inbound traffic:
# any new connection arriving on WAN that has NOT been dst-nat'd is dropped.
# The `dstnat_k8s_*` rules below mark inbound 80/443 as dst-nat'd, which lets
# them through this filter.
resource "routeros_ip_firewall_filter" "defconf_forward_drop_wan_new" {
  chain                = "forward"
  action               = "drop"
  connection_state     = "new"
  connection_nat_state = "!dstnat"
  in_interface_list    = "WAN"
  comment              = "defconf: drop all from WAN not DSTNATed"
}

# ── NAT: srcnat (outbound masquerade) ────────────────────────────────────────

resource "routeros_ip_firewall_nat" "masquerade" {
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = "WAN"
  ipsec_policy       = "out,none"
  comment            = "defconf: masquerade"
}

# ── NAT: dstnat (port-forward to k8s ingress, with hairpin) ──────────────────
# Mirrors the old TP-Link Archer VR400 forwards on the eth WAN: 80/tcp and
# 443/tcp from the public IP land on the cluster ingress VIP.
#
# `dst_address_type = "local"` matches any address the router itself owns —
# both the dynamic WAN address and the LAN management IP.  We exclude the LAN
# subnet so that requests to `https://192.168.1.1/` still reach the router's
# webfig instead of being dst-nat'd to the cluster.  The net effect: traffic
# to 80/443 on the *public* IP gets dst-nat'd whether it arrives on WAN
# (external) or on bridge (LAN client resolving the public DNS name) — i.e.
# hairpin/NAT-loopback works without a second pair of rules.
#
# The matching srcnat rule (`hairpin_masq` below) rewrites the source of LAN
# clients that hit the cluster via this dst-nat path so that return packets
# come back through the router rather than the cluster replying directly.

locals {
  cluster_ingress_ports = {
    http  = { port = 80 }
    https = { port = 443 }
  }

  lan_subnet = "192.168.1.0/24"
}

resource "routeros_ip_firewall_nat" "dstnat_k8s" {
  for_each = local.cluster_ingress_ports

  chain            = "dstnat"
  action           = "dst-nat"
  protocol         = "tcp"
  dst_port         = each.value.port
  dst_address_type = "local"
  dst_address      = "!${local.lan_subnet}"
  to_addresses     = var.cluster_ingress_ip
  to_ports         = each.value.port
  comment          = "k8s ingress: ${each.key}"
}

resource "routeros_ip_firewall_nat" "hairpin_masq" {
  chain       = "srcnat"
  action      = "masquerade"
  src_address = local.lan_subnet
  dst_address = var.cluster_ingress_ip
  comment     = "hairpin: masquerade LAN → cluster ingress"
}
