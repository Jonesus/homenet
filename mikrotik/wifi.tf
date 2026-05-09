# ── WiFi CAPsMAN manager (runs on RB5009) ───────────────────────────────────

resource "routeros_wifi_capsman" "manager" {
  enabled    = true
  interfaces = ["bridge"]
}

# ── Security profile ─────────────────────────────────────────────────────────

resource "routeros_wifi_security" "home" {
  name                 = "home"
  authentication_types = ["wpa2-psk", "wpa3-psk"]
  passphrase           = var.wifi_password
}

# ── Datapath — client traffic forwarded locally on cAP ax's bridge ───────────

resource "routeros_wifi_datapath" "home" {
  name   = "home"
  bridge = "bridge"
}

# ── WiFi configuration profiles (pushed to CAPs via provisioning rules) ───────

resource "routeros_wifi_configuration" "band_24" {
  name = "home-2.4ghz"
  ssid = "AsiaOnPihVintage"
  mode = "ap"
  security = {
    passphrase         = var.wifi_password
    ft                 = "yes"
    ft_over_ds         = "yes"
    ft_preserve_vlanid = "yes"
  }
  steering = {
    rrm = "yes"
    wnm = "yes"
  }
  datapath = { bridge = "bridge" }
  channel  = { band = "2ghz-ax" }
}

resource "routeros_wifi_configuration" "band_5" {
  name = "home-5ghz"
  ssid = "AsiaOnPihvi"
  mode = "ap"
  security = {
    passphrase         = var.wifi_password
    ft                 = "yes"
    ft_over_ds         = "yes"
    ft_preserve_vlanid = "yes"
  }
  steering = {
    rrm = "yes"
    wnm = "yes"
  }
  datapath = { bridge = "bridge" }
  channel  = { band = "5ghz-ax" }
}

# ── Provisioning rules — auto-apply config to CAPs by band ───────────────────

resource "routeros_wifi_provisioning" "band_24" {
  action               = "create-dynamic-enabled"
  supported_bands      = ["2ghz-ax"]
  master_configuration = routeros_wifi_configuration.band_24.name
}

resource "routeros_wifi_provisioning" "band_5" {
  action               = "create-dynamic-enabled"
  supported_bands      = ["5ghz-ax"]
  master_configuration = routeros_wifi_configuration.band_5.name
}
