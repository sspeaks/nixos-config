# flake-parts Migration — Design

## Problem

`flake.nix` is a single ~170-line file mixing concerns:

- Hand-rolled `forEachSystem` / `pkgsFor` / `treefmtFor` boilerplate
- 7 `nixosConfigurations` declared verbatim, each repeating `lib.nixosSystem { specialArgs = ...; modules = [...]; }`
- 4 `homeConfigurations` doing the same
- `packages`, `overlays`, `formatter`, `checks`, `devShells`, `templates` all inline
- Pre-commit hook lives in `.githooks/` and depends on a manual `git config core.hooksPath` step in the dev shell

This works but doesn't scale: adding a host means editing the central file, and adding a new cross-cutting concern (e.g. linting) means more boilerplate for every system.

## Goal

Migrate to [flake-parts](https://flake.parts) and reorganize outputs into per-concern flake modules under `flake-modules/`, adopting the relevant ecosystem modules:

- `treefmt-nix` (already used; switch to its flake-parts module)
- `git-hooks.nix` (replaces `.githooks/`)
- `easy-hosts` (auto-discover `hosts/`)
- `home-manager` flake-parts integration (for module helpers)
- `flake-root` (drives `treefmt`'s `projectRootFile`)
- `numtide/devshell` (replaces `mkShell`)

## Non-goals

- Rewriting individual host modules, home modules, or package derivations
- Adding new lint hooks (deadnix/statix/nil) — out of scope, can be added later
- Migrating the `haskell-template` to `haskell-flake`
- Changing CI workflows (those just call `nix flake check` / `nix build`)

## Top-level `flake.nix`

```nix
{
  description = "NixOS Config";
  inputs = {
    # existing inputs unchanged ...

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    easy-hosts.url = "github:tgirlcloud/easy-hosts";
    easy-hosts.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    flake-root.url = "github:srid/flake-root";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        # ecosystem flake modules
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks.flakeModule
        inputs.devshell.flakeModule
        inputs.flake-root.flakeModule
        inputs.easy-hosts.flakeModule
        inputs.home-manager.flakeModules.home-manager

        # local flake modules
        ./flake-modules/systems.nix
        ./flake-modules/hosts.nix
        ./flake-modules/home.nix
        ./flake-modules/packages.nix
        ./flake-modules/overlays.nix
        ./flake-modules/devshell.nix
        ./flake-modules/treefmt.nix
        ./flake-modules/git-hooks.nix
        ./flake-modules/templates.nix
        ./flake-modules/modules.nix
      ];
    };

  nixConfig = { /* unchanged */ };
}
```

## `flake-modules/` layout

```
flake-modules/
├── systems.nix      # perSystem: pkgs setup, allowUnfree, overlays
├── hosts.nix        # easy-hosts: auto-discover ./hosts, override nixpi5
├── home.nix         # 4 standalone home-manager configurations
├── packages.nix     # perSystem.packages = import ../packages { inherit pkgs; }
├── overlays.nix     # flake.overlays.default + lib.overlayList
├── devshell.nix     # numtide devshell with sops/age/ssh-to-age/nom
├── treefmt.nix      # programs.nixpkgs-fmt enabled, projectRootFile via flake-root
├── git-hooks.nix    # treefmt + nix flake check hooks, auto-install on enter
├── templates.nix    # haskell-template
└── modules.nix      # nixosModules / homeManagerModules exports
```

Each module owns one concern and is small enough to read at a glance.

## Per-module specs

### `systems.nix`

Replaces `pkgsFor`. Sets `pkgs` for every `perSystem` block to a configured `nixpkgs` with `allowUnfree` and the project overlays applied.

```nix
{ inputs, ... }: {
  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = import ../overlays.nix;
    };
  };
}
```

### `hosts.nix`

Uses `easy-hosts` to auto-discover `hosts/`, with a per-host override for `nixpi5` (which uses `nixos-raspberrypi.lib.nixosSystem` instead of `nixpkgs.lib.nixosSystem`).

```nix
{ inputs, self, ... }: {
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
        modules = [ inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base ];
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

Adding a host = `mkdir hosts/foo` with a `default.nix`. No central edit needed for standard NixOS hosts.

The `hosts/common/` directory is shared infra and should be excluded from auto-discovery (easy-hosts allows directory filtering via `hosts` overrides; if not, rename to `hosts-common/` and reference explicitly — verify during implementation).

### `home.nix`

Standalone home-manager configs (not tied to a NixOS host). Stays explicit because easy-hosts is NixOS-only.

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
in {
  flake.homeConfigurations = {
    "sspeaks@NixOS-WSL"     = mkHome "x86_64-linux"   [ ../home/sspeaks.nix ../home/features/sops ];
    "sspeaks@blog"          = mkHome "x86_64-linux"   [ ../home/sspeaks-blog.nix ];
    "sspeaks@darwin"        = mkHome "aarch64-darwin" [ ../home/sspeaks.nix ../home/features/sops ];
    "sspeaks@aarch64-linux" = mkHome "aarch64-linux"  [ ../home/sspeaks.nix ../home/features/sops ];
  };
}
```

### `packages.nix`

```nix
{
  perSystem = { pkgs, ... }: {
    packages = import ../packages { inherit pkgs; };
  };
}
```

`packages/default.nix` already returns an attrset keyed by package name — flake-parts picks them up directly into `packages.${system}` and they participate in `nix flake check`.

### `overlays.nix`

Preserves both existing exports verbatim:

```nix
{
  flake.overlays.default = final: prev:
    let applied = builtins.foldl'
      (acc: ov: acc // (ov final (prev // acc))) { }
      (import ../overlays.nix);
    in applied;
  flake.lib.overlayList = import ../overlays.nix;
}
```

### `devshell.nix`

```nix
{
  perSystem = { pkgs, config, ... }: {
    devshells.default = {
      name = "nixos-config";
      packages = with pkgs; [ sops age ssh-to-age nix-output-monitor ];
      commands = [
        { name = "fmt";   help = "Format the tree";  command = "nix fmt"; }
        { name = "check"; help = "Run flake checks"; command = "nix flake check"; }
      ];
    };
  };
}
```

The `devshell` flake module also sets `devShells.default` for compatibility with `nix develop`.

### `treefmt.nix`

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

The `treefmt-nix` flake module automatically wires:
- `formatter.${system} = config.treefmt.build.wrapper`
- `checks.${system}.treefmt = config.treefmt.build.check self`

So the existing hand-rolled `formatter` and `checks.formatting` outputs go away — replaced with equivalents under the same names (modulo the rename `formatting` → `treefmt` in `checks`).

### `git-hooks.nix`

```nix
{
  perSystem = { config, ... }: {
    pre-commit = {
      check.enable = true;
      settings.hooks.treefmt.enable = true;
    };
    devshells.default.devshell.startup.pre-commit-install.text =
      config.pre-commit.installationScript;
  };
}
```

This:
- Adds `checks.${system}.pre-commit` (formatting verified in CI via `nix flake check`)
- Auto-installs the git pre-commit hook on `nix develop`
- Replaces `.githooks/pre-commit` (deleted) and removes the `git config core.hooksPath .githooks` shellHook

### `templates.nix`

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

### `modules.nix` (new export)

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

Pure addition — exposes existing modules under a stable interface.

## Behavior preservation

After migration the following must still work identically:

- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` for every host
  (`nixpi`, `NixOS-WSL`, `NixOS-WSL-work`, `nixos-azure`, `vm`, `asahi`, `nixpi5`)
- `nix build .#homeConfigurations."sspeaks@<host>".activationPackage` for all 4
- `nix build .#packages.<system>.<pkg>` for every package in `packages/`
- `nix fmt` — formats the tree the same way
- `nix flake check` — passes; now includes `pre-commit` and `treefmt` checks
- `nix develop` — provides the same tools (sops, age, ssh-to-age, nom) plus the new `fmt`/`check` commands; auto-installs pre-commit hook
- `nix flake init -t .#haskell-template` — works
- `self.overlays.default` and `self.lib.overlayList` — unchanged consumers see identical outputs
- `nixConfig.extra-substituters` block at the end of `flake.nix` — preserved

## Migration order (high-level; detailed plan in writing-plans)

1. Add new inputs (`flake-parts`, `easy-hosts`, `git-hooks`, `devshell`, `flake-root`)
2. Create `flake-modules/` skeleton, port outputs one module at a time
3. After each module, verify the relevant outputs still build (`nix flake show`, targeted `nix build`)
4. Delete old inline definitions only after the replacement is verified
5. Delete `.githooks/` and the `core.hooksPath` shellHook last
6. Final verification: `nix flake check` clean

## Risks

- **`easy-hosts` conventions vs `hosts/common/`**: auto-discovery may try to treat `hosts/common/` as a host. Mitigation: use easy-hosts' explicit-include or rename. Verify early.
- **`nixpi5` custom builder**: easy-hosts' `perClass.builder` API needs verification on current version. If unsupported, fall back to declaring `nixpi5` outside easy-hosts (still simpler than today).
- **`pkgs` instance for home-manager configs**: today uses `pkgsFor.${system}` (with overlays). The new path uses the same construction; verify `home/features/sops` etc. still resolve identically.
- **`checks.formatting` → `checks.treefmt` rename**: any external CI referencing the old name needs updating. Repo's own CI calls `nix flake check` (no specific name), so likely safe — verify `.github/workflows/`.
- **Input bloat**: 5 new inputs. All small, all `nixpkgs.follows`-pinned, so no nixpkgs duplication.

## Open questions resolved

- Scope: full migration (confirmed)
- Ecosystem modules: all six (confirmed)
- Host strategy: auto-discover via easy-hosts with `nixpi5` override (confirmed)
- git-hooks: replace `.githooks/`, treefmt + flake-check hooks, no extra linters yet (confirmed)
