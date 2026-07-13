# Surface temporary-fixes.nix obsolescence notices under `nix flake check`
# WITHOUT building the (large) NixOS host / Home Manager closures.
#
# `mkNotice`/`lib.warnIf` only emit when the value they wrap is *forced*, and the
# only place those wrapped packages (and the asahi host module) get pulled in is
# the host/home closures. So we register one trivial "eval-only" check per
# closure: it forces the closure's `drvPath` (which instantiates every input
# derivation and therefore fires the notices during `nix flake check`'s
# evaluation phase) but wraps it in `builtins.unsafeDiscardStringContext` so the
# stub derivation does NOT take the closure as a build dependency. Result:
# `nix flake check --all-systems` evaluates every host/home and prints any active
# notice, while only the tiny stubs are ever built.
#
# Tradeoff (intentional): this verifies each closure *evaluates*, not that it
# *builds*. Use `nixos-rebuild build` / `home-manager build` for a real build.
#
# Checks are keyed by each configuration's own system so plain `nix flake check`
# only touches the current machine's closures; `--all-systems` evaluates them
# all (foreign systems are evaluated, never built).
{ inputs, self, ... }:
let
  lib = inputs.nixpkgs.lib;

  # Check attr names must be CLI-friendly; home config names contain '@'
  # (e.g. "sspeaks@NixOS-WSL"), so fold it into a plain separator.
  sanitize = lib.replaceStrings [ "@" ] [ "-at-" ];

  # evalOnly pkgs name drv: a trivial derivation that forces `drv.drvPath` (to
  # fire eval-time notices) but discards its string context so building this
  # stub never builds `drv`.
  evalOnly = pkgs: name: drv:
    pkgs.runCommandLocal "eval-${name}"
      { ref = builtins.unsafeDiscardStringContext drv.drvPath; }
      ''printf '%s\n' "$ref" > "$out"'';

  nixosClosures = lib.mapAttrsToList
    (name: cfg: rec {
      inherit (cfg.pkgs.stdenv.hostPlatform) system;
      checkName = "nixos-${name}";
      check = evalOnly cfg.pkgs checkName cfg.config.system.build.toplevel;
    })
    self.nixosConfigurations;

  homeClosures = lib.mapAttrsToList
    (name: cfg: rec {
      inherit (cfg.pkgs.stdenv.hostPlatform) system;
      checkName = "home-${sanitize name}";
      check = evalOnly cfg.pkgs checkName cfg.activationPackage;
    })
    self.homeConfigurations;

  allClosures = nixosClosures ++ homeClosures;

  systems = lib.unique (map (c: c.system) allClosures);
in
{
  flake.checks = lib.genAttrs systems (system:
    lib.listToAttrs
      (map (c: lib.nameValuePair c.checkName c.check)
        (lib.filter (c: c.system == system) allClosures)));
}
