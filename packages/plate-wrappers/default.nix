# Shared DPMS/logout actions for hypridle and wlogout.
# Detect the active compositor at call time: NIRI_SOCKET takes precedence
# over HYPRLAND_INSTANCE_SIGNATURE. With neither set, exit non-zero with an
# error rather than guessing a compositor or silently doing nothing.

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
