# homenet

OpenTofu infrastructure-as-code for home network devices.

## Prerequisites

The devcontainer includes everything needed: `tofu`, `sops`, `age`, `sshpass`.

## One-time setup

### 1. Generate an age keypair

```bash
mkdir -p ~/.age
age-keygen -o ~/.age/homenet.key
```

Copy the public key printed to stdout (`age1...`).

### 2. Configure SOPS

Edit [.sops.yaml](.sops.yaml) and replace `age1REPLACE_WITH_YOUR_PUBLIC_KEY` with your public key.

### 3. Export the age key path

Add to `~/.bashrc` (already set in devcontainer if using the persistent history mount):

```bash
export SOPS_AGE_KEY_FILE=~/.age/homenet.key
```

### 4. Create encrypted secrets

```bash
cat > /tmp/secrets.tfvars <<EOF
routeros_password  = "CURRENT_ADMIN_PASSWORD"
tofu_user_password = "$(openssl rand -base64 24)"
EOF
sops --encrypt /tmp/secrets.tfvars > mikrotik/secrets.tfvars.enc
rm /tmp/secrets.tfvars
```

## Deploying to a router

### Step 1: Bootstrap TLS (once per device)

The RouterOS REST API requires HTTPS, which needs a certificate assigned first.
The bootstrap script handles this automatically over SSH:

```bash
make bootstrap
```

For a different host or credentials:

```bash
bash scripts/bootstrap-tls.sh 192.168.X.X admin "PASSWORD"
```

### Step 2: Initialize OpenTofu

```bash
make init
```

Commit the generated `mikrotik/.terraform.lock.hcl` — it pins the provider hash.

### Step 3: Import existing router state

IP services already exist on a fresh router and must be imported before the first apply.
Get the actual IDs first:

```bash
curl -sk -u admin:PASSWORD https://192.168.88.1/rest/ip/service
```

Import each service by name (the provider uses service names, not RouterOS `*N` IDs):

```bash
cd /workspaces/homenet
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) routeros_ip_service.telnet  telnet
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) routeros_ip_service.ftp     ftp
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) routeros_ip_service.www     www
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) routeros_ip_service.ssh     ssh
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) routeros_ip_service.www_ssl www-ssl
tofu -chdir=mikrotik import -var-file=<(sops -d mikrotik/secrets.tfvars.enc) routeros_ip_service.api     api
```

### Step 4: Plan and apply

```bash
make plan   # review changes
make apply  # apply
```

### Step 5: Switch to the dedicated management user

After the `iac` user is created by the apply, update `secrets.tfvars.enc` to use it:

```bash
sops mikrotik/secrets.tfvars.enc
```

Set `routeros_password` to the value of `tofu_user_password`, and `routeros_username = "iac"`.
Re-run `make plan` — expect zero changes.

## Ongoing workflow

```bash
make plan    # preview changes
make apply   # apply changes
make fmt     # format .tf files
make validate # validate configuration
```

## Structure

```
homenet/
├── .sops.yaml              — age encryption recipients
├── Makefile                — convenience targets
├── scripts/
│   └── bootstrap-tls.sh   — one-time TLS bootstrap per device
└── mikrotik/               — RB5009 at 192.168.88.1
    ├── versions.tf         — provider version pin
    ├── providers.tf        — routeros provider config
    ├── variables.tf        — variable declarations
    ├── secrets.tfvars.enc  — SOPS-encrypted credentials (committed)
    ├── main.tf             — identity, IP services, management user
    └── outputs.tf
```

## Secrets

Credentials are stored encrypted using [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).
The encrypted file (`secrets.tfvars.enc`) is committed to git. The age private key lives
at `~/.age/homenet.key` — never committed, never leaves the machine.

The `Makefile` targets use bash process substitution (`<(sops -d ...)`) to pass decrypted
secrets directly to OpenTofu without writing them to disk.

## Known provider quirks

- Use `routeros_system_user` (not `routeros_user`) for router user management.
- `routeros_ip_service` import IDs are service names (e.g., `ssh`), not RouterOS `*N` IDs.
- Warnings about `Field 'dynamic'` and `Field 'proto'` are harmless schema gaps in the provider — ignore them.
- `make apply` is interactive. In non-interactive shells, add `-auto-approve` to the tofu command.
