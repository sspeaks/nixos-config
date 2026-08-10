# Plate XIV compositor-detection wrappers (D24, Batch 2).
#
# hypridle's config and wlogout's config are compositor-agnostic protocol
# consumers (ext-idle-notify-v1 / plain shell commands) — only the specific
# actions they invoke are Hyprland-coupled (`hyprctl dispatch ...`). Rather
# than forking the idle daemon or the logout menu per compositor, these three
# wrapper binaries branch on the active compositor at call time and dispatch
# to the verified equivalent command. hypridle/wlogout call these binaries by
# name instead of hardcoding `hyprctl` strings (Switch/Trinity wire the call
# sites; this file only owns the wrapper contract itself).
#
# Detection: `$NIRI_SOCKET` is set by niri for the lifetime of a niri
# session (confirmed present as a literal env-var name inside the built
# `nixpkgs#niri` binary via `strings`) and `$HYPRLAND_INSTANCE_SIGNATURE` is
# set by Hyprland the same way (confirmed the same way against the locally
# installed `hyprctl` binary) — both are genuine runtime signals, not guesses.
#
# Commands dispatched:
#   plate-dpms-on   -> niri: `niri msg action power-on-monitors`
#                      hypr: `hyprctl dispatch dpms on`
#   plate-dpms-off  -> niri: `niri msg action power-off-monitors`
#                      hypr: `hyprctl dispatch dpms off`
#   plate-logout    -> niri: `niri msg action quit`
#                      hypr: `hyprctl dispatch exit`
#
# All three niri subcommands (`power-on-monitors`, `power-off-monitors`,
# `quit`) were verified empirically against the real, locally built
# `nixpkgs#niri` 26.04 binary's `niri msg action --help` output — none of
# these names were guessed (D24 explicitly forbids that for the two
# power-*-monitors names; `quit` was already confirmed live in
# home/features/niri/config.kdl.nix).
#
# If neither environment variable is present (e.g. a TTY or an unsupported
# compositor), the wrapper exits non-zero with a clear error instead of
# silently no-op'ing or guessing a fallback command.

{ pkgs }:

let
  lib = pkgs.lib;

  mkWrapper = { name, niriArgs, hyprArgs }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.niri pkgs.hyprland ];
      text = ''
        if [ -n "''${NIRI_SOCKET:-}" ]; then
          exec niri msg action ${niriArgs}
        elif [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          exec hyprctl dispatch ${hyprArgs}
        else
          echo "${name}: no supported compositor detected (neither \$NIRI_SOCKET nor \$HYPRLAND_INSTANCE_SIGNATURE is set)" >&2
          exit 1
        fi
      '';
      meta = {
        description = "Plate XIV compositor-detection wrapper: ${name}";
        mainProgram = name;
        platforms = lib.platforms.linux;
      };
    };
in
{
  plate-dpms-on = mkWrapper {
    name = "plate-dpms-on";
    niriArgs = "power-on-monitors";
    hyprArgs = "dpms on";
  };

  plate-dpms-off = mkWrapper {
    name = "plate-dpms-off";
    niriArgs = "power-off-monitors";
    hyprArgs = "dpms off";
  };

  plate-logout = mkWrapper {
    name = "plate-logout";
    niriArgs = "quit";
    hyprArgs = "exit";
  };
}
