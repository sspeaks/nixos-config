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
| `asahi` | aarch64-linux | Apple Silicon Mac — Niri desktop with Hyprland fallback |

## Standalone Home-Manager Profiles

| Profile | Arch | Use case |
|---------|------|----------|
| `sspeaks@NixOS-WSL` | x86_64-linux | WSL without NixOS module |
| `sspeaks@blog` | x86_64-linux | Blog server (minimal) |
| `sspeaks@darwin` | aarch64-darwin | macOS workstation |
| `sspeaks@aarch64-linux` | aarch64-linux | Generic aarch64 Linux |

## Repository Structure

```
flake.nix           # Flake entrypoint
flake-modules/      # Hosts, home profiles, packages, checks, and development shell
  treefmt.nix       # nixpkgs-fmt via treefmt-nix
temporary-fixes.nix # Upstream workarounds and obsolescence checks
overlays.nix        # Nixpkgs overlays and custom packages
hosts/
  common/          # Shared config: global defaults, sops, user definitions
  <host>/          # Per-host NixOS configurations
home/
  global/          # Shared home-manager defaults
  features/        # Opt-in home-manager feature modules (git, zsh, sops, etc.)
  sspeaks.nix      # Full home profile
  sspeaks-blog.nix  # Minimal blog server profile
modules/           # Custom NixOS service modules (wireguard, minecraft, etc.)
packages/          # Custom Nix packages (copilot-cli, gac, etc.)
secrets/           # SOPS-encrypted secrets (age-encrypted YAML)
scripts/           # Maintenance scripts (bootstrap, update helpers)
```

## Quick Start

### Rebuild locally

These commands may build packages locally. For cache-only remote deployment,
use `./deploy <hostname>` or [update the fleet](#updating-the-fleet).

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

`./update-fleet` updates the selected always-on machines using a temporary,
locked Nix runtime. A working Nix installation is the only additional local
bootstrap prerequisite: Bash, Git, `gh`, OpenSSH and the required GNU tools
are supplied without installing them globally or entering `nix develop`.

```bash
./update-fleet --check          # report only: reachability, cache state, drift
./update-fleet                  # bump inputs, publish via CI, then activate
./update-fleet --no-update      # redeploy current main without bumping inputs
./update-fleet --only proxy     # restrict to one host (repeatable)
./update-fleet --prefetch-only  # copy closures to the hosts, activate by hand
```

The fleet launcher defaults to its own checkout, regardless of the current
directory. Use `--repo PATH` to select another checkout. Standalone `./deploy`
continues to default to the current directory, with `--flake-dir PATH` as its
override. The equivalent packaged commands are `nix run .#update-fleet -- ...`
and `nix run .#deploy -- ...`; packaged fleet invocation defaults to the current
directory unless `--repo` is supplied.

Update/publish mode requires an authenticated GitHub account (`gh auth login`),
a clean checkout at the current `origin/main`, and permission to push and merge
the update PR. Nix supplies `gh`, not credentials. From the checkout, authenticate
without globally installing it:

```bash
nix --extra-experimental-features 'nix-command flakes' shell \
  --no-write-lock-file --inputs-from . nixpkgs#gh -c gh auth login
```

`--check` and `--no-update` do not require GitHub authentication.
All target access requires independently verified SSH host keys and the normal
unprivileged SSH account; deployment also requires noninteractive `sudo` and
the target's NixOS deployment tools. No remote dependencies are installed.
Host-key aliases from the fleet table apply consistently to probes and
deployment; standalone deploy accepts `--host-key-alias ALIAS`. Do not bypass
host-key verification or trust an unverified `ssh-keyscan` result.

**Targets never build.** CI builds closures and publishes them to Cachix;
deployment refuses cache misses instead of compiling on low-memory hosts.
Cache-only deployment also supports an `aarch64-darwin` controller without a
local Linux builder, subject to the evaluation limitation below.

The update path waits for successful PR checks for the exact update commit,
merges only that head, then selects the exact merge commit in detached-HEAD
state while waiting for its cache workflow. The checkout and expected closure
are checked again during deployment; unexpected drift stops the run.
Failures leave branches, PRs and local changes available for inspection, not
automatically reset. To resume after a publication failure, select a clean
reviewed commit with published closures and use `--no-update`.

Activation proceeds from lower-impact hosts to the public edge:
`raspberrytimemachine`, `vidbox`, `nixpi4-bare`, `nixpi5`, then `proxy`.
Fresh SSH, the expected running closure, and zero failed systemd units are
required **before the rollback guard can be disarmed**. Failed probes are
failures, not zero counts. The operator must still independently verify the
management path and affected services, then explicitly confirm disarm.
An activation or health failure stops the run before the next host, leaving an
armed guard to recover the previous boot configuration. Do not retry blindly
while a guard is pending.

Activation uses `./deploy --test`; use the printed `deploy --switch` command
(or `./deploy` with those arguments) for each verified host to make its exact
configuration persistent. Active or unknown Time Machine sessions require an
additional confirmation. `--auto-merge` skips only the merge prompt, never
activation confirmations.

Each mode summarizes every selected host. Unreachable or uncached hosts are
skipped while eligible hosts continue, but incomplete runs, declined
activations, and failed verification return nonzero. Drift alone in `--check`
is not a failure. `--check` does not change Git or targets, though startup and
evaluation may fetch local tooling/cache metadata. `--prefetch-only` writes
target stores; without `--no-update` it still updates inputs and publishes a PR.
Activation requires a terminal; unattended publication/prefetch requires
`--prefetch-only --auto-merge`.

Limitations:

- `nixpi4-bare` needs an `aarch64-linux` builder even during evaluation because
  its Haskell workload uses import-from-derivation. Use a controller of that
  architecture or configure a matching remote builder.
- Configurations outside the fleet table are reported as unmanaged.

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

ARM jobs use `ubuntu-24.04-arm`; use a self-hosted aarch64 runner if that label
is unavailable for the repository.

### CI variables/secrets

Set the repository secret `CACHIX_AUTH_TOKEN` to publish to the `sspeaks-nix`
cache. It is exposed only to each job's final publish step, never to builds.

### sops-nix safety in CI

CI builds closures and the Pi installation image without activating them.
sops-nix decryption happens on target hosts using their age keys, not in CI.

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
