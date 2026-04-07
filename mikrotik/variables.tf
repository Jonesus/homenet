variable "routeros_host" {
  description = "Router REST API base URL"
  type        = string
  default     = "https://192.168.88.1"
}

variable "routeros_username" {
  description = "RouterOS username for OpenTofu"
  type        = string
  default     = "admin"
}

variable "routeros_password" {
  description = "RouterOS password (provided via SOPS-encrypted tfvars)"
  type        = string
  sensitive   = true
}

variable "tofu_user_password" {
  description = "Password for the dedicated tofu management user"
  type        = string
  sensitive   = true
}
