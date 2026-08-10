# Plate XIV niri module — ACTIVE default session (Batch 2/D20, D33).
#
# niri is registered as the default session (D33): `hosts/asahi/desktop.nix`
# sets `defaultSession = "niri"` and lists both `pkgs.niri` and the
# hand-rolled hyprland-sessions derivation in `sessionPackages` (D33 requires
# Hyprland remain selectable as a safe fallback — SDDM shows both entries).
# Hyprland files, config, and packages are all preserved; only the greeter
# default changes.
#
# `pkgs.niri` ships `niri.desktop` natively (`providedSessions = ["niri"]`,
# `Exec=niri-session`) — no Exec-path patching needed (D19).
#
# portalPackage stays null here: xdg-desktop-portal-gnome / per-desktop
# portal routing is Tank's D21 (hosts/asahi/desktop.nix), landed
# separately. Do not set portalPackage until D21 lands, to avoid two
# owners racing the same portal wiring.

{ asahiPaths, pkgs, ... }:

let
  plate = import ../theme/plate.nix;
in
{
  wayland.windowManager.niri = {
    enable = true;

    # Direct nixpkgs package, no pin/patch — the previous "Tank's
    # packages.nix" plan was stale/over-engineered per Tank's own review;
    # niri 26.04 builds and runs as-is on this host (verified via
    # `nix build nixpkgs#niri`, D20).
    package = pkgs.niri;

    # Installs niri's systemd units (used by niri-session) now that a
    # non-null package is present.
    systemd.enable = true;

    # D21 landed in hosts/asahi/desktop.nix (per-desktop portal routing,
    # xdg-desktop-portal-gnome for niri). Leave null here — portal wiring
    # is owned by desktop.nix, not this HM module, to avoid dual ownership.
    portalPackage = null;

    # Non-null package present — validate the generated config.kdl at
    # build time via `niri validate` (HM module's checkPhase, D20/D30).
    checkConfig = true;

    # KDL configuration generated from Plate XIV tokens and the immutable
    # wallpaper store path (D5/D6).  wallpaper is asahiPaths.wallpaper,
    # supplied via home-manager.extraSpecialArgs — not re-imported here.
    extraConfig = (import ./config.kdl.nix) {
      inherit plate;
      wallpaper = asahiPaths.wallpaper;
    };
  };
}
