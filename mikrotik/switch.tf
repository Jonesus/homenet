# ════════════════════════════════════════════════════════════════════════════
#  Switch — homenet-sw (RB5009 at 192.168.1.2, dumb L2 mode)
#  All resources in this file target the routeros.switch provider alias.
# ════════════════════════════════════════════════════════════════════════════

# ── System identity ──────────────────────────────────────────────────────────

resource "routeros_system_identity" "sw" {
  provider = routeros.switch
  name     = "homenet-sw"
}

# ── Dedicated OpenTofu management user ──────────────────────────────────────

resource "routeros_system_user" "sw_mgmt" {
  provider = routeros.switch
  name     = "iac"
  password = var.switch_tofu_password
  group    = "write"
  comment  = "OpenTofu management account"
  address  = "192.168.1.0/24"
}

# ── IP services ──────────────────────────────────────────────────────────────

resource "routeros_ip_service" "sw_telnet" {
  provider = routeros.switch
  numbers  = "telnet"
  port     = 23
  disabled = true
}

resource "routeros_ip_service" "sw_ftp" {
  provider = routeros.switch
  numbers  = "ftp"
  port     = 21
  disabled = true
}

resource "routeros_ip_service" "sw_www" {
  provider = routeros.switch
  numbers  = "www"
  port     = 80
  disabled = true
}

# Requires TLS bootstrap to be complete before applying (run `make bootstrap-switch` first)
resource "routeros_ip_service" "sw_www_ssl" {
  provider = routeros.switch
  numbers  = "www-ssl"
  port     = 443
  disabled = false
}

resource "routeros_ip_service" "sw_api" {
  provider = routeros.switch
  numbers  = "api"
  port     = 8728
  disabled = true
}

resource "routeros_ip_service" "sw_ssh" {
  provider = routeros.switch
  numbers  = "ssh"
  port     = 22
  disabled = false
  address  = "192.168.1.0/24"
}

# ── Bridge ───────────────────────────────────────────────────────────────────
# All physical ports are members of a single bridge — this is what makes the
# device act as a transparent L2 switch.  The SFP+ port is the uplink to the
# router; the ethernet ports serve downstream devices.  Traffic between any two
# ports is forwarded at L2 with no routing involved.

resource "routeros_bridge" "sw_bridge" {
  provider = routeros.switch
  name     = "bridge"
  comment  = "LAN bridge — all ports"
}

# ── Bridge ports (ether1–ether8 + sfp-sfpplus1) ──────────────────────────────

resource "routeros_bridge_port" "sw_ether1" {
  provider  = routeros.switch
  interface = "ether1"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_ether2" {
  provider  = routeros.switch
  interface = "ether2"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_ether3" {
  provider  = routeros.switch
  interface = "ether3"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_ether4" {
  provider  = routeros.switch
  interface = "ether4"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_ether5" {
  provider  = routeros.switch
  interface = "ether5"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_ether6" {
  provider  = routeros.switch
  interface = "ether6"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_ether7" {
  provider  = routeros.switch
  interface = "ether7"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_ether8" {
  provider  = routeros.switch
  interface = "ether8"
  bridge    = routeros_bridge.sw_bridge.name
}

resource "routeros_bridge_port" "sw_sfp_sfpplus1" {
  provider  = routeros.switch
  interface = "sfp-sfpplus1"
  bridge    = routeros_bridge.sw_bridge.name
}

# ── Management IP ─────────────────────────────────────────────────────────────
# Static address on the bridge so the switch is reachable for management.

resource "routeros_ip_address" "sw_mgmt" {
  provider  = routeros.switch
  address   = "192.168.1.2/24"
  interface = routeros_bridge.sw_bridge.name
  comment   = "Switch management IP"
}

# ── Default route ─────────────────────────────────────────────────────────────

resource "routeros_ip_route" "sw_default" {
  provider    = routeros.switch
  dst_address = "0.0.0.0/0"
  gateway     = "192.168.1.1"
}
