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
  ttl     = "300"
  comment = "LG ThinQ appliance → rethink Service LoadBalancer"
}
resource "routeros_ip_dns_record" "rethink_cloud_extra" {
  type    = "A"
  name    = "rethink.lan"
  address = "192.168.1.212"
  ttl     = "300"
  comment = "LG ThinQ appliance → rethink Service LoadBalancer"
}

# The LG firmware has common.lgthinq.com:443 hard-coded for the post-pairing
# setup handshake. Per the rethink wiki we redirect it to our rethink-cloud
# instance. After initial setup completes the appliance switches to the
# `hostname` configured in rethink-cloud (rethink.lan), so this rewrite is
# strictly only needed during first run — but leaving it in place is harmless.
resource "routeros_ip_dns_record" "rethink_lgthinq_redirect" {
  type    = "A"
  name    = "common.lgthinq.com"
  address = "192.168.1.212"
  ttl     = "300"
  comment = "Hijack LG cloud → rethink Service (post-pairing handshake)"
}

# valetudo.internal is the rooted Dreame X40 Ultra (Valetudo) web UI. It's a
# physical device on a DHCP reservation (see dhcp.tf, MAC 70:C9:32:93:89:00),
# not a k8s ingress — its UI is plain HTTP on port 80 at 192.168.1.101. This
# more-specific record overrides the *.internal wildcard, which would otherwise
# send the name to ingress-nginx (192.168.1.208) where no such host exists.
# Mirror in AdGuard.
resource "routeros_ip_dns_record" "valetudo" {
  type    = "A"
  name    = "valetudo.internal"
  address = "192.168.1.101"
  ttl     = "300"
  comment = "Dreame X40 Ultra (Valetudo) web UI → DHCP-reserved device IP"
}
