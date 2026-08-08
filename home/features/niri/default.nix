# Plate XIV niri module — configured but dormant.
#
# ACTIVATION PATH:
#   To switch the live session to niri:
#     1. Flip `enable` to true below.
#     2. Set `package` to a non-null niri package (Tank adds it to packages.nix).
#     3. Remove/adjust portalPackage if a different portal is preferred.
#     4. Rebuild and switch session in SDDM/greeter.
#
# While disabled this module is evaluated for syntax coverage but installs
# no session entry, no package, and no portal.  Hyprland remains the active
# compositor.
#
# Do NOT set systemd.enable = true until the session package is present —
# the assertion in the HM niri module requires a non-null package.

{ asahiPaths, ... }:

let
  plate = import ../theme/plate.nix;
in
{
  wayland.windowManager.niri = {
    # ── DORMANT — flip to true when activating the niri session ──────────────
    enable = false;

    # Supply the niri package through Tank's packages.nix when activating.
    # Setting null here prevents any binary being added to PATH and satisfies
    # the HM assertion that systemd.enable requires a non-null package.
    package = null;

    # Disable systemd units while dormant; they require a non-null package.
    systemd.enable = false;

    # No portal during dormancy — do not activate xdg-desktop-portal-gnome
    # until niri is the live session.
    portalPackage = null;

    # Config validation requires a non-null package; skip while dormant.
    checkConfig = false;

    # KDL configuration generated from Plate XIV tokens and the immutable
    # wallpaper store path (D5/D6).  wallpaper is asahiPaths.wallpaper,
    # supplied via home-manager.extraSpecialArgs — not re-imported here.
    extraConfig = (import ./config.kdl.nix) {
      inherit plate;
      wallpaper = asahiPaths.wallpaper;
    };
  };
}
