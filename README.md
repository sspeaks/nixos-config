# nixos-config

Personal NixOS configuration flake managing multiple hosts, home-manager profiles, and custom packages.

## Hosts

| Host | Arch | Description |
|------|------|-------------|
| `nixpi` | aarch64-linux | Raspberry Pi — minimal headless server |
| `nixpi5` | aarch64-linux | Raspberry Pi 5 — Authentik, Home Assistant, SnappyMail, Garage Monitor |
| `NixOS-WSL` | x86_64-linux | WSL dev environment |
| `NixOS-WSL-work` | x86_64-linux | WSL dev environment (work) |
| `nixos-azure` | x86_64-linux | Azure VM — Pogbot, WireGuard, Boggle, VS Code Server |
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
packages/          # Custom Nix packages (copilot-cli, gac, ralph, etc.)
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
