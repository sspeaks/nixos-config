# nixos-config

Personal NixOS configuration flake managing multiple hosts, home-manager profiles, and custom packages.

## Hosts

| Host | Arch | Description |
|------|------|-------------|
| `nixpi` | aarch64-linux | Raspberry Pi 4 — travel router (hostapd AP, dnsmasq, nftables NAT, WireGuard) |
| `nixpi4-services` | aarch64-linux | Home service configuration of the same Pi 4 as `nixpi` — Pogbot and Boggle |
| `nixpi5` | aarch64-linux | Raspberry Pi 5 — Authentik, Home Assistant, SnappyMail, Garage Monitor |
| `NixOS-WSL` | x86_64-linux | WSL dev environment |
| `NixOS-WSL-work` | x86_64-linux | WSL dev environment (work) |
| `nixos-azure` | x86_64-linux | Minimal Azure VM baseline |
| `pogbot` | x86_64-linux | Azure VM service host — Pogbot, WireGuard, Boggle |
| `vm` | x86_64-linux | Minimal test/dev VM |
| `asahi` | aarch64-linux | Apple Silicon Mac — GNOME desktop workstation |

### Proposed Pi 4 services identity transition

`nixpi4-services` is the proposed replacement for the `nixpi4-bare` flake output
and machine hostname. The role suffix distinguishes it from the retained
`nixpi` travel router; “services” covers both Pogbot and Boggle without implying
that this is a second Pi or limiting future workloads to bots.

The owner must approve the proposal and coordinate deployment; the live name
remains `nixpi4-bare` until activation. This branch provides no compatibility
output under the old name or the rejected hardware-only `nixpi4` name. `nixpi` is
still a separate travel-router configuration for this same physical Pi, not a
second server; switching to it stops the home workloads and requires a reboot
because the network stacks differ.

The owner must coordinate deployment after review/merge and after CI publishes
the newly named system closure. `./deploy` refuses commits not on `main`; do not
bypass that guard to deploy an unmerged rename. From a clean checkout of the
reviewed commit, on a controller that can evaluate the Pi configuration:

```bash
# Keep using the existing, verified SSH alias during the hostname transition.
./deploy --dry-run --ssh-target nixpi4-bare nixpi4-services
./deploy --test --ssh-target nixpi4-bare nixpi4-services
# Only after a successful test and a fresh SSH connection:
./deploy --switch --ssh-target nixpi4-bare nixpi4-services
```

The SSH alias used during transition must resolve independently of the old
hostname (for example, to the known LAN address), not through an old `.local`
name. Then update the operator's SSH/known_hosts aliases to `nixpi4-services`, verifying
the existing SSH host-key fingerprint rather than accepting an unexpected key.
`./deploy nixpi4-services` defaults its SSH target to `nixpi4-services`.

Hostname-derived mDNS/Avahi advertisements become `nixpi4-services.local` when enabled;
this NixOS configuration currently has Avahi disabled. The system derivation
name changes, so the new closure must be built and cached, although unchanged
package dependencies can be reused. SSH host keys, SOPS recipients and
`secrets/nixpi.yaml`, WireGuard keys and overlay address `10.10.0.3`, and the
edge's IP-based reverse-proxy targets do not change.

Boggle currently uses a Linux-only `cabal2nix` import during evaluation. A
Darwin controller without that evaluated dependency can fail even before
deployment; use a Linux controller with the evaluation dependency available.
A cached system closure alone does not remove that evaluation requirement.

Rollback means selecting the previous NixOS generation (and restoring the old
operator aliases as needed), not deploying `nixpi`: that would select the
travel-router workload instead.

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

- `nixos-azure` on `x86_64-linux`
- `pogbot` on `x86_64-linux`
- `vidbox` on `x86_64-linux`
- `nixpi` and `nixpi4-services` on `aarch64-linux`
- `nixpi5` on `aarch64-linux`
- `asahi` on `aarch64-linux`
- `proxy` on `aarch64-linux`, alongside the Pi SD image

It runs on pushes to `main` and can also be started manually via `workflow_dispatch`.

Note: the aarch64 build jobs use the GitHub Actions ARM runner label `ubuntu-24.04-arm`. If ARM hosted runners are unavailable for your repository plan, switch those jobs to a self-hosted aarch64 runner.

### CI variables/secrets

Set this in GitHub repository settings to push build outputs to Cachix:

- Secret `CACHIX_AUTH_TOKEN`

The workflow is pinned to cache name `sspeaks-nix`.

If the secret is missing, the workflow fails fast before building.

### sops-nix safety in CI

This pipeline intentionally performs build-only operations:

- Builds `config.system.build.toplevel`
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
