output "router_identity" {
  description = "The configured system name of the router"
  value       = routeros_system_identity.this.name
}

output "mgmt_user" {
  description = "The dedicated OpenTofu management user"
  value       = routeros_system_user.mgmt.name
}
