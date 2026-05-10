# ════════════════════════════════════════════════════════════════════════════
#  Static DNS records on the router resolver.
#
#  The DHCP options in dhcp.tf advertise AdGuard (192.168.1.209) as the
#  primary resolver and the router (192.168.1.1) as the fallback. AdGuard
#  owns a wildcard rewrite for *.internal → 192.168.1.208 (ingress-nginx
#  LB), but the router knows nothing about that domain — its upstream is
#  the ISP, which returns NXDOMAIN.
#
#  systemd-resolved (and other stub resolvers) can stick to whichever
#  server is currently answering, so a brief AdGuard hiccup leaves a
#  client pinned to 192.168.1.1 — at which point every *.internal lookup
#  fails until the client is nudged back to AdGuard. Mirror the wildcard
#  on the router so .internal resolves either way.
#
#  This duplicates the AdGuard rewrite. If the ingress LB IP ever moves,
#  update both places (and infrastructure/adguard/loadbalancer.yaml in
#  the public/ kustomize tree).
# ════════════════════════════════════════════════════════════════════════════

resource "routeros_ip_dns_record" "internal_wildcard" {
  type            = "A"
  name            = "internal"
  address         = "192.168.1.208"
  match_subdomain = true
  comment         = "*.internal → ingress-nginx; mirrors AdGuard rewrite"
}

# rethink-cloud.internal is the hostname the LG ThinQ washer/dryer is paired
# with (set during SoftAP pairing by rethink-setup). It must hit the rethink
# Service's MetalLB IP directly, not ingress-nginx — the appliance speaks the
# ThinQ TLS protocol on ports 4433/46030/47878, not HTTP. This more-specific
# record overrides the *.internal wildcard above. Mirror in AdGuard.
resource "routeros_ip_dns_record" "rethink_cloud" {
  type    = "A"
  name    = "rethink-cloud.internal"
  address = "192.168.1.212"
  comment = "LG ThinQ appliance → rethink Service LoadBalancer"
}
