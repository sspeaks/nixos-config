# flake-parts Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the monolithic `flake.nix` to flake-parts, splitting outputs into per-concern modules under `flake-modules/`, and adopting the ecosystem modules `treefmt-nix`, `git-hooks.nix`, `easy-hosts`, `home-manager`, `flake-root`, and `numtide/devshell`.

**Architecture:** `flake.nix` becomes a thin shell that calls `flake-parts.lib.mkFlake` and imports a list of small flake modules (one per concern). The hand-rolled `forEachSystem`/`pkgsFor` boilerplate is replaced by flake-parts' `perSystem`. Hosts are auto-discovered from `hosts/` via `easy-hosts`, with `nixpi5` getting a per-host override for its custom builder.

**Tech Stack:** Nix flakes, flake-parts, easy-hosts, treefmt-nix, git-hooks.nix, numtide/devshell, flake-root, home-manager.

**Reference spec:** `docs/superpowers/specs/2026-04-29-flake-parts-migration-design.md`

**Verification model:** This migration has no traditional unit tests. The "tests" are:
- `nix flake check --all-systems` — must pass
- `nix flake show` — exposes all expected attributes
- `nix build .#<target> --dry-run` — every host, home config, and package builds

Each task ends by running the relevant verification commands and then committing.

**Important — pre-commit hook:** Until Task 7 deletes `.githooks/`, the existing hook runs `treefmt` on staged `.nix` files and may fail with "treefmt not found" outside `nix develop`. Either run all `git commit` commands inside `nix develop`, or pass `-c core.hooksPath=/dev/null` to git for commits in this plan. The plan assumes the latter for reliability.

---

## File Structure

**New files (created by this plan):**
- `flake-modules/systems.nix` — `perSystem._module.args.pkgs` setup
- `flake-modules/overlays.nix` — `flake.overlays.default` + `flake.lib.overlayList`
- `flake-modules/packages.nix` — `perSystem.packages` from `./packages`
- `flake-modules/templates.nix` — `flake.templates`
- `flake-modules/treefmt.nix` — treefmt-nix configuration
- `flake-modules/devshell.nix` — numtide devshell
- `flake-modules/hosts.nix` — easy-hosts NixOS configurations
- `flake-modules/home.nix` — standalone home-manager configurations
- `flake-modules/git-hooks.nix` — pre-commit hooks
- `flake-modules/modules.nix` — `flake.nixosModules` export

**Modified files:**
- `flake.nix` — rewritten as a thin flake-parts shell
- `flake.lock` — regenerated as inputs are added

**Deleted files:**
- `.githooks/pre-commit` (and the `.githooks/` directory)

**Untouched (verified preserved):**
- All `hosts/*` modules
- All `home/*` modules
- All `packages/*` derivations
- `overlays.nix` (the existing data file at repo root)
- `treefmt.nix` (the existing data file at repo root) — *will be deleted in Task 3 once contents are inlined into the flake module*
- `modules/`, `secrets/`, `scripts/`

---

## Task 1: Add new flake inputs

Pulls in flake-parts and the ecosystem modules without changing any outputs yet. The flake must still evaluate identically.

**Files:**
- Modify: `flake.nix` (inputs block only)
- Modify: `flake.lock` (regenerated)

- [ ] **Step 1: Add the new inputs**

Edit `flake.nix`. Inside the `inputs = { ... };` block, before the closing `};`, add:

```nix
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    easy-hosts = {
      url = "github:tgirlcloud/easy-hosts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-root = {
      url = "github:srid/flake-root";
    };
```

- [ ] **Step 2: Update the lock file**

Run: `nix flake lock`
Expected: New entries appear in `flake.lock` for `flake-parts`, `easy-hosts`, `git-hooks`, `devshell`, `flake-root`. No errors.

- [ ] **Step 3: Verify the flake still evaluates**

Run: `nix flake show --all-systems 2>&1 | head -30`
Expected: Same output as before (nixosConfigurations, homeConfigurations, packages, etc.). No eval errors. The new inputs are unused but present.

- [ ] **Step 4: Commit**

```bash
git -c core.hooksPath=/dev/null add flake.nix flake.lock
git -c core.hooksPath=/dev/null commit -m "Add flake-parts ecosystem inputs

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 2: Convert flake.nix to flake-parts skeleton (systems, overlays, packages, templates)

Replaces the imperative `outputs` function with `flake-parts.lib.mkFlake`, importing four local modules that cover the simplest outputs first: system pkgs setup, overlays, packages, and templates. After this task, `nix flake show` should expose the same `packages.${system}.*`, `overlays.default`, `lib.overlayList`, and `templates.haskell-template` as before — but `nixosConfigurations`, `homeConfigurations`, `formatter`, `checks`, and `devShells` will be **temporarily missing**. They are restored by Tasks 3–7.

**Files:**
- Create: `flake-modules/systems.nix`
- Create: `flake-modules/overlays.nix`
- Create: `flake-modules/packages.nix`
- Create: `flake-modules/templates.nix`
- Modify: `flake.nix` (rewritten)

- [ ] **Step 1: Create `flake-modules/systems.nix`**

```nix
{ inputs, ... }:
{
  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = import ../overlays.nix;
    };
  };
}
```

- [ ] **Step 2: Create `flake-modules/overlays.nix`**

```nix
{
  flake.overlays.default = final: prev:
    let
      applied = builtins.foldl'
        (acc: ov: acc // (ov final (prev // acc))) { }
        (import ../overlays.nix);
    in
    applied;
  flake.lib.overlayList = import ../overlays.nix;
}
```

- [ ] **Step 3: Create `flake-modules/packages.nix`**

```nix
{
  perSystem = { pkgs, ... }: {
    packages = import ../packages { inherit pkgs; };
  };
}
```

- [ ] **Step 4: Create `flake-modules/templates.nix`**

```nix
{
  flake.templates = {
    haskell-template = {
      path = ../haskell-template;
      description = "Just a few files to help bootstrap a haskell project with nix";
    };
  };
}
```

- [ ] **Step 5: Rewrite `flake.nix`**

Replace the entire `outputs = inputs@{ ... }: let ... in { ... };` block with the flake-parts shell. Keep `description`, `inputs`, and `nixConfig` exactly as they are. The new `outputs`:

```nix
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        ./flake-modules/systems.nix
        ./flake-modules/overlays.nix
        ./flake-modules/packages.nix
        ./flake-modules/templates.nix
      ];
    };
```

The full `flake.nix` after this step is: (a) `description`, (b) `inputs` (unchanged from Task 1), (c) `outputs` (the block above), (d) `nixConfig` (unchanged).

- [ ] **Step 6: Verify packages still build**

Run: `nix flake show --all-systems 2>&1 | grep -E '(packages|overlays|templates|lib)' | head -20`
Expected: `packages.x86_64-linux.askGPT4`, `packages.x86_64-linux.ralph`, etc., plus `overlays.default`, `templates.haskell-template`. Same set as before.

Run: `nix build .#packages.x86_64-linux.askGPT4 --dry-run --no-link 2>&1 | tail -5`
Expected: No errors; either "would build" or "would fetch" lines.

Run: `nix eval .#lib.overlayList --apply 'l: builtins.length l' 2>&1`
Expected: `2` (matches the existing two-overlay list).

- [ ] **Step 7: Confirm temporary loss of host/home/devshell outputs**

Run: `nix flake show --all-systems 2>&1 | grep -E '(nixosConfigurations|homeConfigurations|devShells|formatter|checks)' || echo "absent (expected at this stage)"`
Expected: `absent (expected at this stage)`. These come back in Tasks 3–7.

- [ ] **Step 8: Commit**

```bash
git -c core.hooksPath=/dev/null add flake.nix flake-modules/
git -c core.hooksPath=/dev/null commit -m "Migrate flake.nix to flake-parts skeleton

Move systems/overlays/packages/templates outputs into
flake-modules/. Hosts, home configs, devshell, formatter,
and checks are restored in subsequent commits.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 3: Restore formatter and checks via treefmt-nix flake module

Reintroduces `formatter.${system}` and `checks.${system}.treefmt` (renamed from `checks.${system}.formatting`) using the treefmt-nix flake module, with `flake-root` providing `projectRootFile`. Deletes the now-redundant root `treefmt.nix` data file.

**Files:**
- Create: `flake-modules/treefmt.nix`
- Modify: `flake.nix` (imports list)
- Delete: `treefmt.nix` (root)

- [ ] **Step 1: Create `flake-modules/treefmt.nix`**

```nix
{
  perSystem = { config, ... }: {
    treefmt = {
      inherit (config.flake-root) projectRootFile;
      programs.nixpkgs-fmt.enable = true;
    };
  };
}
```

- [ ] **Step 2: Add the treefmt-nix and flake-root modules + the local module to `flake.nix`**

In `flake.nix`, change the `imports = [ ... ];` list inside `mkFlake` to:

```nix
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
        ./flake-modules/systems.nix
        ./flake-modules/overlays.nix
        ./flake-modules/packages.nix
        ./flake-modules/templates.nix
        ./flake-modules/treefmt.nix
      ];
```

- [ ] **Step 3: Delete the root `treefmt.nix`**

Run: `rm treefmt.nix`

The contents are now expressed inline in `flake-modules/treefmt.nix`. `flake-root` finds the project root by looking for `flake.nix`, which replaces the old `projectRootFile = "flake.nix";` line.

- [ ] **Step 4: Verify formatter is exposed and runs**

Run: `nix flake show --all-systems 2>&1 | grep formatter`
Expected: `formatter.x86_64-linux`, `formatter.aarch64-linux`, `formatter.aarch64-darwin`, `formatter.x86_64-darwin` (whatever `systems` resolves to).

Run: `nix fmt -- --no-cache --fail-on-change 2>&1 | tail -5`
Expected: Exit 0; tree already formatted (no changes).

- [ ] **Step 5: Verify the formatting check is exposed**

Run: `nix flake show --all-systems 2>&1 | grep -A2 'checks\.x86_64-linux'`
Expected: A `treefmt` entry under `checks.x86_64-linux` (the integration auto-creates this).

Run: `nix build .#checks.x86_64-linux.treefmt --no-link 2>&1 | tail -5`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git -c core.hooksPath=/dev/null add flake.nix flake-modules/treefmt.nix
git -c core.hooksPath=/dev/null rm treefmt.nix
git -c core.hooksPath=/dev/null commit -m "Adopt treefmt-nix flake module

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 4: Restore devShells via numtide/devshell

Reintroduces `devShells.default` using the `numtide/devshell` flake module, exposing the same tools as before plus `fmt`/`check` commands. The `core.hooksPath` shellHook is **not** carried over — Task 7's git-hooks integration replaces it.

**Files:**
- Create: `flake-modules/devshell.nix`
- Modify: `flake.nix` (imports list)

- [ ] **Step 1: Create `flake-modules/devshell.nix`**

```nix
{
  perSystem = { pkgs, ... }: {
    devshells.default = {
      name = "nixos-config";
      packages = with pkgs; [ sops age ssh-to-age nix-output-monitor ];
      commands = [
        { name = "fmt"; help = "Format the tree"; command = "nix fmt"; }
        { name = "check"; help = "Run flake checks"; command = "nix flake check"; }
      ];
    };
  };
}
```

- [ ] **Step 2: Add devshell to `flake.nix` imports**

Insert `inputs.devshell.flakeModule` after `inputs.flake-root.flakeModule`, and `./flake-modules/devshell.nix` after `./flake-modules/treefmt.nix`. Final imports list:

```nix
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
        inputs.devshell.flakeModule
        ./flake-modules/systems.nix
        ./flake-modules/overlays.nix
        ./flake-modules/packages.nix
        ./flake-modules/templates.nix
        ./flake-modules/treefmt.nix
        ./flake-modules/devshell.nix
      ];
```

- [ ] **Step 3: Verify the dev shell builds and contains the tools**

Run: `nix flake show --all-systems 2>&1 | grep devShells`
Expected: `devShells.x86_64-linux.default` (and same for other systems).

Run: `nix develop --command bash -c 'command -v sops && command -v age && command -v ssh-to-age && command -v nom && echo OK'`
Expected: Four paths printed, then `OK`.

Run: `nix develop --command bash -c 'menu 2>&1 | head -20'`
Expected: A devshell menu listing `fmt` and `check` commands (devshell auto-defines a `menu` command).

- [ ] **Step 4: Commit**

```bash
git -c core.hooksPath=/dev/null add flake.nix flake-modules/devshell.nix
git -c core.hooksPath=/dev/null commit -m "Adopt numtide devshell flake module

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 5: Restore nixosConfigurations via easy-hosts

Reintroduces all 7 `nixosConfigurations` using `easy-hosts` auto-discovery on `hosts/`. The `nixpi5` host gets a per-host override that switches the builder to `nixos-raspberrypi.lib.nixosSystem` and adds the `raspberry-pi-5.base` module. `hosts/common/` is **not** a host — easy-hosts must be told to skip it.

> **Caveat:** `easy-hosts`' API for "exclude this directory" / "use this builder" varies by version. The implementation below uses the `hosts` attribute to declare overrides explicitly while leaving auto-discovery on. If `autoConstruct` discovers `hosts/common`, an explicit `hosts.common = null;` (or whatever the version supports for exclusion) is the fallback. If `easy-hosts` cannot be made to skip `common/` cleanly, see the **Fallback** at the bottom of this task.

**Files:**
- Create: `flake-modules/hosts.nix`
- Modify: `flake.nix` (imports list)

- [ ] **Step 1: Create `flake-modules/hosts.nix`**

```nix
{ inputs, self, ... }:
{
  easyHosts = {
    shared = {
      specialArgs = { inherit inputs; outputs = self; };
    };
    autoConstruct = true;
    path = ../hosts;
    hosts = {
      nixpi5 = {
        arch = "aarch64";
        class = "rpi5";
        modules = [
          inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        ];
      };
    };
    perClass = class: {
      builder =
        if class == "rpi5"
        then inputs.nixos-raspberrypi.lib.nixosSystem
        else null;
    };
  };
}
```

- [ ] **Step 2: Add easy-hosts to `flake.nix` imports**

Insert `inputs.easy-hosts.flakeModule` after `inputs.devshell.flakeModule`, and `./flake-modules/hosts.nix` after `./flake-modules/devshell.nix`.

- [ ] **Step 3: First eval — confirm hosts are discovered correctly**

Run: `nix flake show --all-systems 2>&1 | grep -A20 nixosConfigurations`
Expected: Exactly these 7 entries: `nixpi`, `NixOS-WSL`, `NixOS-WSL-work`, `nixos-azure`, `vm`, `asahi`, `nixpi5`. No `common`.

If `common` appears or any host is missing, apply the **Fallback** below before continuing.

- [ ] **Step 4: Verify each host evaluates**

Run for each host:
```bash
for host in nixpi NixOS-WSL NixOS-WSL-work nixos-azure vm asahi nixpi5; do
  echo "=== $host ===";
  nix eval ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" 2>&1 | tail -1;
done
```
Expected: Each line prints a `/nix/store/...-nixos-system-*.drv` path. No errors.

- [ ] **Step 5: Verify a representative host actually builds (dry-run)**

Run: `nix build .#nixosConfigurations.NixOS-WSL.config.system.build.toplevel --dry-run 2>&1 | tail -5`
Expected: No errors; "would build" or "would fetch" lines.

Run: `nix build .#nixosConfigurations.nixpi5.config.system.build.toplevel --dry-run 2>&1 | tail -5`
Expected: No errors. This validates the `nixos-raspberrypi` builder override.

- [ ] **Step 6: Commit**

```bash
git -c core.hooksPath=/dev/null add flake.nix flake-modules/hosts.nix
git -c core.hooksPath=/dev/null commit -m "Adopt easy-hosts for nixosConfigurations

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Fallback for Step 3 (if easy-hosts trips on `hosts/common/`)

If `nix flake show` reveals a spurious `common` host or eval fails because easy-hosts tries to instantiate `hosts/common/`, replace `flake-modules/hosts.nix` with the explicit-list variant below, then redo Steps 3–5:

```nix
{ inputs, self, ... }:
let
  mkHost = path: extraModules: inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; outputs = self; };
    modules = [ path ] ++ extraModules;
  };
in
{
  flake.nixosConfigurations = {
    nixpi          = mkHost ../hosts/nixpi          [ ];
    NixOS-WSL      = mkHost ../hosts/nixosWSL       [ ];
    NixOS-WSL-work = mkHost ../hosts/nixosWSL-work  [ ];
    nixos-azure    = mkHost ../hosts/nixos-azure    [ ];
    vm             = mkHost ../hosts/vm             [ ];
    asahi          = mkHost ../hosts/asahi          [ ];
    nixpi5 = inputs.nixos-raspberrypi.lib.nixosSystem {
      specialArgs = { inherit inputs; outputs = self; nixos-raspberrypi = inputs.nixos-raspberrypi; };
      modules = [
        ../hosts/nixpi5
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
      ];
    };
  };
}
```

If the fallback is used, also remove `inputs.easy-hosts.flakeModule` from the `flake.nix` imports list, since easy-hosts is no longer being used.

---

## Task 6: Restore homeConfigurations

Reintroduces the 4 standalone home-manager configurations. easy-hosts is NixOS-only, so these stay as an explicit attrset built with a small helper.

**Files:**
- Create: `flake-modules/home.nix`
- Modify: `flake.nix` (imports list — also adds the home-manager flake module)

- [ ] **Step 1: Create `flake-modules/home.nix`**

```nix
{ inputs, self, ... }:
let
  pkgsFor = system: import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = import ../overlays.nix;
  };
  mkHome = system: modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor system;
      extraSpecialArgs = { inherit inputs; outputs = self; };
      inherit modules;
    };
in
{
  flake.homeConfigurations = {
    "sspeaks@NixOS-WSL"     = mkHome "x86_64-linux"   [ ../home/sspeaks.nix ../home/features/sops ];
    "sspeaks@blog"          = mkHome "x86_64-linux"   [ ../home/sspeaks-blog.nix ];
    "sspeaks@darwin"        = mkHome "aarch64-darwin" [ ../home/sspeaks.nix ../home/features/sops ];
    "sspeaks@aarch64-linux" = mkHome "aarch64-linux"  [ ../home/sspeaks.nix ../home/features/sops ];
  };
}
```

- [ ] **Step 2: Add the home-manager flake module + local module to `flake.nix` imports**

Insert `inputs.home-manager.flakeModules.home-manager` after `inputs.easy-hosts.flakeModule`, and `./flake-modules/home.nix` after `./flake-modules/hosts.nix`.

- [ ] **Step 3: Verify each home configuration evaluates**

```bash
for cfg in 'sspeaks@NixOS-WSL' 'sspeaks@blog' 'sspeaks@darwin' 'sspeaks@aarch64-linux'; do
  echo "=== $cfg ===";
  nix eval ".#homeConfigurations.\"$cfg\".activationPackage.drvPath" 2>&1 | tail -1;
done
```
Expected: Each line prints a `/nix/store/...-home-manager-generation.drv` path.

- [ ] **Step 4: Verify a representative home config builds (dry-run)**

Run: `nix build '.#homeConfigurations."sspeaks@NixOS-WSL".activationPackage' --dry-run 2>&1 | tail -5`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git -c core.hooksPath=/dev/null add flake.nix flake-modules/home.nix
git -c core.hooksPath=/dev/null commit -m "Migrate homeConfigurations to flake-parts module

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 7: Adopt git-hooks.nix and remove `.githooks/`

Replaces the manual `.githooks/pre-commit` script with declarative pre-commit hooks managed by `git-hooks.nix`. Auto-installs the hook on `nix develop`.

**Files:**
- Create: `flake-modules/git-hooks.nix`
- Modify: `flake.nix` (imports list)
- Modify: `flake-modules/devshell.nix` (add startup hook installer)
- Delete: `.githooks/pre-commit`, then `.githooks/` directory

- [ ] **Step 1: Create `flake-modules/git-hooks.nix`**

```nix
{
  perSystem = {
    pre-commit = {
      check.enable = true;
      settings.hooks.treefmt.enable = true;
    };
  };
}
```

- [ ] **Step 2: Update `flake-modules/devshell.nix` to install the hook on shell entry**

Replace the current contents with:

```nix
{
  perSystem = { pkgs, config, ... }: {
    devshells.default = {
      name = "nixos-config";
      packages = with pkgs; [ sops age ssh-to-age nix-output-monitor ];
      commands = [
        { name = "fmt"; help = "Format the tree"; command = "nix fmt"; }
        { name = "check"; help = "Run flake checks"; command = "nix flake check"; }
      ];
      devshell.startup.pre-commit-install.text = config.pre-commit.installationScript;
    };
  };
}
```

- [ ] **Step 3: Add git-hooks to `flake.nix` imports**

Insert `inputs.git-hooks.flakeModule` after `inputs.home-manager.flakeModules.home-manager`, and `./flake-modules/git-hooks.nix` after `./flake-modules/home.nix`.

- [ ] **Step 4: Delete `.githooks/`**

Run:
```bash
git -c core.hooksPath=/dev/null rm .githooks/pre-commit
rmdir .githooks
```

- [ ] **Step 5: Verify the pre-commit check is exposed**

Run: `nix flake show --all-systems 2>&1 | grep -A3 'checks\.x86_64-linux'`
Expected: A `pre-commit` entry under `checks.x86_64-linux` alongside `treefmt`.

Run: `nix build .#checks.x86_64-linux.pre-commit --no-link 2>&1 | tail -5`
Expected: No errors.

- [ ] **Step 6: Verify the hook auto-installs on shell entry**

Run: `git config --local --unset core.hooksPath 2>/dev/null; rm -f .git/hooks/pre-commit; nix develop --command true && ls -la .git/hooks/pre-commit`
Expected: `.git/hooks/pre-commit` exists and is executable (installed by `pre-commit`).

- [ ] **Step 7: Verify the hook actually runs on commit**

Run a no-op commit through the hook to confirm it executes without error:
```bash
git commit --allow-empty -m "test: pre-commit hook smoke test"
git reset --soft HEAD~1
```
Expected: First command succeeds. The hook runs `treefmt` against zero staged files (no-op success).

- [ ] **Step 8: Commit (now using the new hook, no bypass needed)**

```bash
git add flake.nix flake-modules/git-hooks.nix flake-modules/devshell.nix
git commit -m "Replace .githooks with git-hooks.nix flake module

Removes manual core.hooksPath shellHook in favor of
declarative pre-commit hooks installed automatically
on 'nix develop'.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 8: Export reusable modules via `flake.nixosModules`

Adds a new `nixosModules` output exposing the modules under `modules/` so other flakes (or future-you) can consume them with `inputs.nixos-config.nixosModules.<name>`.

**Files:**
- Create: `flake-modules/modules.nix`
- Modify: `flake.nix` (imports list)

- [ ] **Step 1: Create `flake-modules/modules.nix`**

```nix
{
  flake.nixosModules = {
    minecraft     = ../modules/minecraft.nix;
    postgresql    = ../modules/postgresql.nix;
    ptunnelServer = ../modules/ptunnelServer.nix;
    udp2rawServer = ../modules/udp2rawServer.nix;
    wireguard     = ../modules/wireguard;
  };
}
```

- [ ] **Step 2: Add `./flake-modules/modules.nix` to the `flake.nix` imports list**

Append to the local-modules section. Final imports list at this point:

```nix
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
        inputs.devshell.flakeModule
        inputs.easy-hosts.flakeModule
        inputs.home-manager.flakeModules.home-manager
        inputs.git-hooks.flakeModule
        ./flake-modules/systems.nix
        ./flake-modules/overlays.nix
        ./flake-modules/packages.nix
        ./flake-modules/templates.nix
        ./flake-modules/treefmt.nix
        ./flake-modules/devshell.nix
        ./flake-modules/hosts.nix
        ./flake-modules/home.nix
        ./flake-modules/git-hooks.nix
        ./flake-modules/modules.nix
      ];
```

- [ ] **Step 3: Verify the export**

Run: `nix flake show --all-systems 2>&1 | grep -A6 nixosModules`
Expected: All 5 entries: `minecraft`, `postgresql`, `ptunnelServer`, `udp2rawServer`, `wireguard`.

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake-modules/modules.nix
git commit -m "Export reusable nixosModules

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 9: Final verification and cleanup

End-to-end check that the migration preserves all outputs and that CI will be green.

**Files:** None modified.

- [ ] **Step 1: Run the full flake check**

Run: `nix flake check --all-systems 2>&1 | tail -30`
Expected: Exit 0. No errors.

- [ ] **Step 2: Confirm every host evaluates**

```bash
for host in nixpi NixOS-WSL NixOS-WSL-work nixos-azure vm asahi nixpi5; do
  nix eval ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" >/dev/null 2>&1 \
    && echo "OK $host" || echo "FAIL $host";
done
```
Expected: Seven `OK` lines.

- [ ] **Step 3: Confirm every home configuration evaluates**

```bash
for cfg in 'sspeaks@NixOS-WSL' 'sspeaks@blog' 'sspeaks@darwin' 'sspeaks@aarch64-linux'; do
  nix eval ".#homeConfigurations.\"$cfg\".activationPackage.drvPath" >/dev/null 2>&1 \
    && echo "OK $cfg" || echo "FAIL $cfg";
done
```
Expected: Four `OK` lines.

- [ ] **Step 4: Confirm every package evaluates**

Run: `nix flake show --all-systems --json 2>/dev/null | nix run nixpkgs#jq -- -r '.packages."x86_64-linux" | keys[]'`
Expected: `askGPT4`, `gac`, `garnet-image`, `local-garnet`, `myCopilot`, `ptunn`, `ralph`, `simc`, `udp2raw` (the 9 packages from `packages/default.nix`).

- [ ] **Step 5: Confirm formatter and overlays**

Run: `nix fmt -- --no-cache --fail-on-change 2>&1 | tail -3`
Expected: Exit 0.

Run: `nix eval .#overlays.default --apply 'o: builtins.typeOf o' 2>&1`
Expected: `"lambda"`.

- [ ] **Step 6: Verify the GitHub Actions workflow command still works**

Run: `nix flake check --all-systems 2>&1 | tail -3`
Expected: Same as Step 1; this is the exact command in `.github/workflows/check.yml`.

- [ ] **Step 7: Final commit if any cleanup occurred (otherwise skip)**

If Steps 1–6 all passed without any file changes, no commit is needed and this task is complete. If any step required edits, commit them:

```bash
git add -A
git commit -m "Final cleanup after flake-parts migration

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Summary of behavior changes

After all 9 tasks:
- `nix flake show` lists the same 7 nixosConfigurations, 4 homeConfigurations, 9 packages, `overlays.default`, `templates.haskell-template`, `formatter.${system}`, and `devShells.${system}.default` as before — plus new outputs: `nixosModules.{minecraft,postgresql,ptunnelServer,udp2rawServer,wireguard}`, `lib.overlayList` (preserved), and `checks.${system}.{treefmt,pre-commit}`.
- `nix fmt` works identically (nixpkgs-fmt under the hood).
- `nix develop` provides the same tools, plus a `menu` command and auto-installs the pre-commit hook.
- Pre-commit formatting still runs on staged `.nix` files; the implementation moved from `.githooks/pre-commit` (manual) to `git-hooks.nix` (declarative).
- `.github/workflows/check.yml` runs the same `nix flake check --all-systems` command, which now also exercises the new `treefmt` and `pre-commit` checks.
