provider "routeros" {
  hosturl  = var.router_host
  username = var.router_username
  password = var.router_password
  insecure = true
}

provider "routeros" {
  alias    = "switch"
  hosturl  = var.switch_host
  username = var.switch_username
  password = var.switch_password
  insecure = true
}
