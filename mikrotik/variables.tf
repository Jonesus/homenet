# ── Router (homenet-gw, 192.168.88.1) ────────────────────────────────────────

variable "router_host" {
  description = "Router REST API base URL"
  type        = string
  default     = "https://192.168.88.1"
}

variable "router_username" {
  description = "RouterOS username for OpenTofu (router)"
  type        = string
  default     = "admin"
}

variable "router_password" {
  description = "RouterOS password for the router (provided via SOPS-encrypted tfvars)"
  type        = string
  sensitive   = true
}

variable "router_tofu_password" {
  description = "Password for the dedicated OpenTofu management user on the router"
  type        = string
  sensitive   = true
}

# ── Switch (homenet-sw, 192.168.88.2) ────────────────────────────────────────

variable "switch_host" {
  description = "Switch REST API base URL"
  type        = string
  default     = "https://192.168.88.2"
}

variable "switch_username" {
  description = "RouterOS username for OpenTofu (switch)"
  type        = string
  default     = "admin"
}

variable "switch_password" {
  description = "RouterOS password for the switch (provided via SOPS-encrypted tfvars)"
  type        = string
  sensitive   = true
}

variable "switch_tofu_password" {
  description = "Password for the dedicated OpenTofu management user on the switch"
  type        = string
  sensitive   = true
}

# ── Shared ────────────────────────────────────────────────────────────────────

variable "wifi_password" {
  description = "Shared WiFi passphrase for home network SSIDs"
  type        = string
  sensitive   = true
}
