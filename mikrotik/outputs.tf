output "router_identity" {
  description = "The configured system name of the router"
  value       = routeros_system_identity.this.name
}

output "router_mgmt_user" {
  description = "The dedicated OpenTofu management user on the router"
  value       = routeros_system_user.mgmt.name
}

output "switch_identity" {
  description = "The configured system name of the switch"
  value       = routeros_system_identity.sw.name
}

output "switch_mgmt_user" {
  description = "The dedicated OpenTofu management user on the switch"
  value       = routeros_system_user.sw_mgmt.name
}

output "switch_mgmt_ip" {
  description = "The management IP address of the switch"
  value       = routeros_ip_address.sw_mgmt.address
}
