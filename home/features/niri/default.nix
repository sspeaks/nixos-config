# Default session on Asahi; hosts/asahi/desktop.nix keeps Hyprland selectable
# as a fallback and owns session registration and portal routing.

{ asahiPaths, pkgs, ... }:

let
  plate = import ../theme/plate.nix;
in
{
  wayland.windowManager.niri = {
    enable = true;

    package = pkgs.niri;

    # niri-session requires these systemd units.
    systemd.enable = true;

    # Avoid competing with the host's per-desktop portal configuration.
    portalPackage = null;

    checkConfig = true;

    # The host supplies the immutable wallpaper path via extraSpecialArgs.
    extraConfig = (import ./config.kdl.nix) {
      inherit plate;
      wallpaper = asahiPaths.wallpaper;
    };
  };
}
