# nixos-config

Personal NixOS configuration flake managing multiple hosts, home-manager profiles, and custom packages.

## Hosts

| Host | Arch | Description |
|------|------|-------------|
| `nixpi` | aarch64-linux | Raspberry Pi 4 — travel router (hostapd AP, dnsmasq, nftables NAT, WireGuard) |
| `nixpi4-bare` | aarch64-linux | Same Pi 4 as `nixpi`, minus the router — plain headless SSH box |
| `nixpi5` | aarch64-linux | Raspberry Pi 5 — Authentik, Home Assistant, SnappyMail, Garage Monitor |
| `NixOS-WSL` | x86_64-linux | WSL dev environment |
| `NixOS-WSL-work` | x86_64-linux | WSL dev environment (work) |
| `nixos-azure` | x86_64-linux | Minimal Azure VM baseline |
| `pogbot` | x86_64-linux | Azure VM service host — Pogbot, WireGuard, Boggle |
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

## Updating the fleet

`./update-fleet` updates every always-on machine in one run:

```bash
./update-fleet --check          # report only: reachability, cache state, drift
./update-fleet                  # bump inputs, publish via CI, then activate
./update-fleet --no-update      # redeploy current main without bumping inputs
./update-fleet --only proxy     # restrict to one host (repeatable)
./update-fleet --prefetch-only  # copy closures to the hosts, activate by hand
```

The rule it enforces is that **nothing ever builds on a target**. Most of this
fleet cannot: `proxy` has 938 MiB of RAM and the two Pi 4s have 1.8 GiB, and the
controller is `aarch64-darwin` with no Linux builder, so it cannot build for any
of them either. Every closure is built once by CI, pushed to Cachix, and only
substituted onto each host. The script refuses to deploy a host whose closure is
not already in the cache rather than letting that host try to build it.

Hosts are activated in ascending order of blast radius — Time Machine box,
`vidbox`, `nixpi4-bare`, `nixpi5`, then the edge — and each is checked for
failed units before the next is touched, so a bad closure stops the run instead
of reaching `proxy`. Activation uses `--test`, keeping `./deploy`'s interactive
dead-man rollback guard; `--switch` per host makes it permanent.

Two known limitations it reports rather than hides:

- `nixpi4-bare` cannot be evaluated on an `aarch64-darwin` controller at all.
  Its Haskell workload uses import-from-derivation, which forces an
  `aarch64-linux` build during evaluation. Deploy it from a machine of its own
  architecture, or configure an `aarch64-linux` remote builder.
- Configurations not in its table are listed as unmanaged, so a new server
  cannot silently go un-updated.

## Host Cache Builds

The workflow [.github/workflows/host-build-cache.yml](.github/workflows/host-build-cache.yml) builds and caches:

- `nixos-azure` on `x86_64-linux`
- `pogbot` on `x86_64-linux`
- `vidbox` on `x86_64-linux`
- `nixpi` and `nixpi4-bare` on `aarch64-linux`
- `nixpi5` on `aarch64-linux`
- `asahi` on `aarch64-linux`
- `proxy` and `raspberrytimemachine` on `aarch64-linux`, alongside the Pi SD image

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
