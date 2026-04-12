# homenet

OpenTofu infrastructure-as-code for home network devices managed as a single project.

| Device | Model | Address | Role |
|--------|-------|---------|------|
| homenet-gw | RB5009 | 192.168.88.1 | Router / CAPsMAN controller |
| homenet-sw | RB5009 | 192.168.88.2 | Dumb L2 switch |

## Prerequisites

The devcontainer includes everything needed: `tofu`, `sops`, `age`, `sshpass`.

## One-time setup

### 1. Generate an age keypair

```bash
age-keygen -o homenet.key
```

Copy the public key printed to stdout (`age1…`). The private key stays local —
it is gitignored and never committed.

### 2. Configure SOPS

Edit [.sops.yaml](.sops.yaml) and replace the placeholder `age1…` value with
your public key.

### 3. Export the age key path

Add to `~/.bashrc` (already set in the devcontainer if using the persistent
history mount):

```bash
export SOPS_AGE_KEY_FILE=/workspaces/homenet/homenet.key
```

### 4. Create the combined secrets file

```bash
cat > /tmp/secrets.tfvars <<EOF
router_username      = "admin"
router_password      = "CURRENT_ROUTER_ADMIN_PASSWORD"
router_tofu_password = "$(openssl rand -base64 24)"
switch_password      = "CURRENT_SWITCH_ADMIN_PASSWORD"
switch_tofu_password = "$(openssl rand -base64 24)"
wifi_password        = "YOUR_WIFI_PASSPHRASE"
EOF
sops --encrypt /tmp/secrets.tfvars > mikrotik/secrets.tfvars.enc
rm /tmp/secrets.tfvars
```

All five passwords live in a single encrypted file under `mikrotik/`.

---

## Deploying the router (first time)

### Step 1: Bootstrap TLS (once)

The RouterOS REST API requires HTTPS, which needs a self-signed certificate
assigned first. The bootstrap script handles this over SSH:

```bash
make bootstrap
```

### Step 2: Initialize OpenTofu

```bash
make init
```

Commit the generated `mikrotik/.terraform.lock.hcl` — it pins the provider hash.

### Step 3: Import existing router resources

IP services and system identity pre-exist on a fresh router and must be
imported before the first apply:

```bash
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_system_identity.this '*'
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.telnet  telnet
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.ftp     ftp
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.www     www
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.www_ssl www-ssl
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.api     api
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.ssh     ssh
```

### Step 4: Plan and apply

```bash
make plan    # review changes
make apply   # apply
```

### Step 5: Switch to the dedicated management user

After the `iac` user is created by the apply, update the secrets file to use it:

```bash
sops mikrotik/secrets.tfvars.enc
```

Set `router_username = "iac"` and `router_password` to the value of
`router_tofu_password`. Re-run `make plan` — expect zero changes.

---

## Deploying the switch (first time)

### Step 1: Bootstrap the switch hardware (once)

**Important:** Disconnect the SFP+ cable from the router before running this.
Both devices ship with 192.168.88.1 as their default IP — connecting them before
the switch IP is changed causes an ARP collision. Plug a laptop directly into
one of the switch's ethernet ports instead.

```bash
make bootstrap-switch
```

This script:
1. Moves ether1 from the factory WAN role into the bridge
2. Assigns management IP 192.168.88.2 on the bridge
3. Adds a default route via 192.168.88.1
4. Removes the factory DHCP server
5. Runs TLS bootstrap at the new IP

After it finishes, reconnect the SFP+ cable to the router.

### Step 2: Import existing switch resources

The bridge, ports, IP services, and system identity pre-exist after bootstrap
and must be imported. Look up the MikroTik internal IDs first:

```bash
# Bridge
curl -sk -u admin: https://192.168.88.2/rest/interface/bridge
# Bridge ports
curl -sk -u admin: https://192.168.88.2/rest/interface/bridge/port
# IP address
curl -sk -u admin: https://192.168.88.2/rest/ip/address
# IP route
curl -sk -u admin: https://192.168.88.2/rest/ip/route
```

Then import using the `*N` IDs from the API responses (example IDs — yours will differ):

```bash
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_system_identity.sw  '*'
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_bridge.sw_bridge    '*1'
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_bridge_port.sw_ether1      '*1'
# … repeat for sw_ether2–sw_ether8 and sw_sfp_sfpplus1
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.sw_telnet  telnet
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.sw_ftp     ftp
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.sw_www     www
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.sw_www_ssl www-ssl
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.sw_api     api
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_service.sw_ssh     ssh
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_address.sw_mgmt  '*1'
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) \
  routeros_ip_route.sw_default '*80000001'
```

### Step 3: Plan and apply

Both devices are managed by the same commands:

```bash
make plan
make apply
```

### Step 4: Switch to the dedicated management user

Same as the router: update `switch_password` to `switch_tofu_password` and set
`switch_username = "iac"` in `mikrotik/secrets.tfvars.enc`, then verify with
`make plan`.

---

## Ongoing workflow

```bash
make plan      # preview changes across both devices
make apply     # apply changes across both devices
make fmt       # format .tf files
make validate  # validate configuration
```

---

## Structure

```
homenet/
├── .sops.yaml                    — age encryption recipients
├── Makefile                      — convenience targets
├── scripts/
│   ├── bootstrap-tls.sh          — one-time TLS bootstrap per device
│   └── bootstrap-switch.sh       — one-time hardware bootstrap for the switch
└── mikrotik/                     — single OpenTofu project for all devices
    ├── versions.tf               — provider version constraint
    ├── providers.tf              — default (router) + routeros.switch alias
    ├── variables.tf              — device-prefixed variables (router_*, switch_*)
    ├── secrets.tfvars.enc        — SOPS-encrypted credentials for both devices
    ├── main.tf                   — router: identity, IP services, management user
    ├── wifi.tf                   — router: CAPsMAN + WiFi configurations
    ├── switch.tf                 — switch: identity, IP services, bridge, ports, routes
    └── outputs.tf                — identity and management IP outputs
```

## Secrets

Credentials are stored encrypted using [SOPS](https://github.com/getsops/sops) +
[age](https://github.com/FiloSottile/age). The single encrypted file
(`mikrotik/secrets.tfvars.enc`) is committed to git. The age private key lives at
`homenet.key` — gitignored, never committed, never leaves the machine.

The `Makefile` targets use bash process substitution (`<(sops -d …)`) to pass
decrypted secrets directly to OpenTofu without writing them to disk.

Variable names in the secrets file:

| Variable | Purpose |
|----------|---------|
| `router_username` | Username for router API (omit to use default `admin`) |
| `router_password` | Router API password |
| `router_tofu_password` | Password for the dedicated `iac` management user on the router |
| `switch_username` | Username for switch API (omit to use default `admin`) |
| `switch_password` | Switch API password |
| `switch_tofu_password` | Password for the dedicated `iac` management user on the switch |
| `wifi_password` | Shared WiFi passphrase pushed to all CAPs via CAPsMAN |

## Known provider quirks

- Use `routeros_system_user` (not `routeros_user`) for user management.
- `routeros_ip_service` import IDs are service names (e.g., `ssh`), not RouterOS `*N` IDs.
- `make apply` is interactive. In non-interactive shells, add `-auto-approve` to the tofu command.
- Switch resources use the `provider = routeros.switch` alias; router resources use the default provider.
