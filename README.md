# nixos-config

Personal NixOS configuration flake managing multiple hosts, home-manager profiles, and custom packages.

## Hosts

| Host | Arch | Description |
|------|------|-------------|
| `nixpi` | aarch64-linux | Raspberry Pi 4 — alternate travel-router configuration (hostapd AP, dnsmasq, nftables NAT); not currently deployed |
| `nixpi4-bare` | aarch64-linux | Deployed configuration of the same Pi 4 — Pogbot and Boggle over WireGuard |
| `nixpi5` | aarch64-linux | Raspberry Pi 5 — Authentik (PostgreSQL 16), Home Assistant, go2rtc, SnappyMail |
| `NixOS-WSL` | x86_64-linux | WSL dev environment |
| `NixOS-WSL-work` | x86_64-linux | WSL dev environment (work) |
| `proxy` | aarch64-linux | Public Azure edge — seven Caddy vhosts and the WireGuard listener |
| `raspberrytimemachine` | aarch64-linux | Raspberry Pi 4 — Time Machine appliance with a USB backup disk; network hostname remains `raspberrypi` |
| `vidbox` | x86_64-linux | Home Hyper-V VM — video streaming and AI coaching |
| `vm` | x86_64-linux | Minimal test/dev VM |
| `asahi` | aarch64-linux | Apple Silicon Mac — GNOME desktop workstation |

## Standalone Home-Manager Profiles

| Profile | Arch | Use case |
|---------|------|----------|
| `sspeaks@NixOS-WSL` | x86_64-linux | WSL without NixOS module |
| `sspeaks@blog` | x86_64-linux | Blog server (minimal) |
| `sspeaks@darwin` | aarch64-darwin | macOS workstation |
| `sspeaks@aarch64-linux` | aarch64-linux | Generic aarch64 Linux |

## Repository Structure

```
flake.nix          # Flake entrypoint — hosts, home profiles, packages, checks
treefmt.nix        # Formatter configuration (nixpkgs-fmt via treefmt-nix)
temporary-fixes.nix # Temporary upstream/workaround fixes to revisit later
overlays.nix       # Nixpkgs overlays (waagent fix, custom packages)
hosts/
  common/          # Shared config: global defaults, sops, user definitions
  <host>/          # Per-host NixOS configurations
home/
  global/          # Shared home-manager config (shell, editor, tools)
  features/        # Opt-in home-manager feature modules (git, zsh, sops, etc.)
  sspeaks.nix      # Full home profile
  sspeaks-blog.nix # Minimal blog server profile
modules/           # Custom NixOS service modules (wireguard, minecraft, etc.)
packages/          # Custom Nix packages (copilot-cli, gac, etc.)
secrets/           # SOPS-encrypted secrets (age-encrypted YAML)
scripts/           # Maintenance scripts (bootstrap, update helpers)
```

## Quick Start

### Deploy a NixOS host

```bash
# Rebuild the current host
sudo nixos-rebuild switch --flake .#<hostname>

# Build with nix-output-monitor (available in devShell)
nom build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### Apply a home-manager profile

```bash
home-manager switch --flake .#sspeaks@darwin
```

### Development shell

```bash
nix develop  # provides: treefmt, sops, age, ssh-to-age, nom
```

### Format all Nix files

```bash
nix fmt
```

### Run checks

```bash
nix flake check
```

## Host Cache Builds

The workflow [.github/workflows/host-build-cache.yml](.github/workflows/host-build-cache.yml) builds and caches:

- `vidbox` on `x86_64-linux`
- `nixpi` and `nixpi4-bare` on `aarch64-linux`
- `nixpi5` on `aarch64-linux`
- `asahi` on `aarch64-linux`
- `proxy` on `aarch64-linux`
- `raspberrytimemachine` as a bootable SD image on `aarch64-linux` (including its system closure)

The workflow runs on pushes to `main` and can also be started manually via `workflow_dispatch`.

`NixOS-WSL`, `NixOS-WSL-work`, and `vm` remain flake configurations but are not
part of this cache workflow. Both Pi 4 variants are built; they are alternatives
for one physical machine, not two deployed hosts.

The `proxyAzureImage` package is a separate Gen2 VHD output. It is not built by
this workflow: image creation needs KVM, which the hosted ARM runner lacks.
Build it on `nixpi5`, where `/dev/kvm` is available.

Note: the aarch64 build jobs use the GitHub Actions ARM runner label `ubuntu-24.04-arm`. If ARM hosted runners are unavailable for your repository plan, switch those jobs to a self-hosted aarch64 runner.

### CI variables/secrets

Set this in GitHub repository settings to push build outputs to Cachix:

- Secret `CACHIX_AUTH_TOKEN`

The workflow is pinned to cache name `sspeaks-nix`.

If the secret is missing, the workflow fails fast before building.

### sops-nix safety in CI

This pipeline intentionally performs build-only operations:

- Builds system closures and the Pi installation image
- Does not run `nixos-rebuild switch`
- Does not run activation scripts

That keeps sops-nix decryption on target hosts where age keys already exist (for example `/var/lib/sops-nix/key.txt`) and avoids storing private age keys in CI.

## Secrets Management

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using age encryption.

- **`.sops.yaml`** — defines which age keys can decrypt each secret file
- **`secrets/common.yaml`** — shared secrets (user password, SSH keys, Copilot tokens)
- **`secrets/<host>.yaml`** — host-specific secrets (WireGuard keys, service tokens)

### Adding a new host's key

1. Get the host's age key from its SSH host key:
   ```bash
   ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
   ```
2. Add the key to `.sops.yaml` under `keys.hosts`
3. Add the host to the relevant `creation_rules` entries
4. Re-encrypt affected secret files:
   ```bash
   sops updatekeys secrets/common.yaml
   ```

### Editing secrets

```bash
sops secrets/common.yaml
```
