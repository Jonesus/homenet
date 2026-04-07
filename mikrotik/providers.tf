provider "routeros" {
  hosturl  = var.routeros_host
  username = var.routeros_username
  password = var.routeros_password
  insecure = true
}
