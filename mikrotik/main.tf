# ── System identity ─────────────────────────────────────────────────────────

resource "routeros_system_identity" "this" {
  name = "homenet-gw"
}

# ── Dedicated OpenTofu management user ──────────────────────────────────────

resource "routeros_system_user" "mgmt" {
  name     = "iac"
  password = var.router_tofu_password
  group    = "write"
  comment  = "OpenTofu management account"
  address  = "192.168.1.0/24"
}

# ── IP services ─────────────────────────────────────────────────────────────

resource "routeros_ip_service" "telnet" {
  numbers  = "telnet"
  port     = 23
  disabled = true
}

resource "routeros_ip_service" "ftp" {
  numbers  = "ftp"
  port     = 21
  disabled = true
}

resource "routeros_ip_service" "www" {
  numbers  = "www"
  port     = 80
  disabled = true
}

# Requires TLS bootstrap to be complete before applying (run `make bootstrap` first)
resource "routeros_ip_service" "www_ssl" {
  numbers  = "www-ssl"
  port     = 443
  disabled = false
}

resource "routeros_ip_service" "api" {
  numbers  = "api"
  port     = 8728
  disabled = true
}

resource "routeros_ip_service" "ssh" {
  numbers  = "ssh"
  port     = 22
  disabled = false
  address  = "192.168.1.0/24"
}

# ── LAN IP on the factory bridge ─────────────────────────────────────────────
# The router ships with `bridge` already configured and carrying 192.168.88.1/24
# on a fresh device (factory id *1 with comment "defconf"). This resource takes
# over that address and changes it to the target management IP.  Import first:
#   tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
#     routeros_ip_address.lan '*1'

resource "routeros_ip_address" "lan" {
  address   = "192.168.1.1/24"
  interface = "bridge"
  comment   = "Router LAN management IP"
}
