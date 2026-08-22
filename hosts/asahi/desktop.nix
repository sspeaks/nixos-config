{ config, pkgs, lib, asahiPaths, ... }:

let
  plate = import ../../home/features/theme/plate.nix;
in
{
  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "where_is_my_sddm_theme";
    extraPackages = with pkgs.kdePackages; [
      qt5compat
      qtsvg
    ];
  };
  services.displayManager.defaultSession = "niri";

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.dconf.enable = true;
  programs.hyprland.enable = true;

  # D33 (Batch 3 gate): niri is now the configured default session, but
  # Hyprland must remain installed AND selectable as a safe fallback.
  # Both sessions are registered here. The hand-rolled hyprland-sessions
  # derivation is kept to strip the broken uwsm variant (original D-batch-1
  # rationale — `hyprland.desktop` from programs.hyprland.enable brings an
  # uwsm-wrapped entry that fails without uwsm units). pkgs.niri ships
  # niri.desktop natively (providedSessions = ["niri"]; verified via
  # `nix eval nixpkgs#niri.providedSessions`).
  services.displayManager.sessionPackages = lib.mkForce [
    pkgs.niri
    (pkgs.runCommand "hyprland-sessions"
      {
        passthru.providedSessions = [ "hyprland" ];
      } ''
      mkdir -p $out/share/wayland-sessions
      cp ${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop $out/share/wayland-sessions/
    '')
  ];

  # niri binary/niri-session must be resolvable on PATH for the greeter to
  # exec the niri.desktop entry's `Exec=niri-session`. home-manager's
  # `wayland.windowManager.niri` module (Trinity's D20, enable=true) already
  # adds `pkgs.niri` to `home.packages`, but that is scoped to the user's
  # home-manager profile activation; `pkgs.niri` is also added to the
  # `environment.systemPackages` list below (mirroring upstream nixpkgs' own
  # `programs.niri` module, which sets BOTH `environment.systemPackages` and
  # `sessionPackages` to `[ cfg.package ]` — verified by reading nixpkgs
  # `nixos/modules/programs/wayland/niri.nix`) so the greeter's session
  # picker has no ordering dependency on home-manager activation.

  # D21 (Batch 2): per-desktop portal routing, not a single shared `common`
  # block. `xdg-desktop-portal-gnome` is added for niri — this matches
  # niri's own upstream-shipped portal preference (verified empirically:
  # `pkgs.niri`'s `share/xdg-desktop-portal/niri-portals.conf` ships
  # `default=gnome;gtk;`) and the nixpkgs `programs.niri` module's own
  # `xdg.portal.config.niri` block, both independently confirming the
  # gnome-over-wlr choice. `xdg-desktop-portal-wlr` is not added.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
    nerd-fonts.iosevka-term
    noto-fonts
  ];

  # D32: UPower required for Quickshell Services.UPower / ControlCenter battery row.
  services.upower.enable = true;

  environment.systemPackages = with pkgs; [
    chromium
    vlc
    iwgtk
    vscodium
    (pkgs.runCommand "code-alias" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.vscodium}/bin/codium $out/bin/code
    '')
    gnumake
    # D19: niri on system PATH so `Exec=niri-session` resolves at the
    # greeter regardless of home-manager activation ordering (see above).
    niri
    # D24: compositor-detection wrappers — see packages/plate-wrappers.
    plate-dpms-on
    plate-dpms-off
    plate-logout
    # D32: system-control backend wrappers for Quickshell ControlCenter.
    # All must be on system PATH (not just HM profile) so Quickshell's
    # Process calls resolve regardless of home-manager activation order.
    plate-battery-status
    plate-brightness-get
    plate-brightness-set
    plate-brightness-step
    plate-volume-get
    plate-volume-set
    plate-volume-step
    plate-volume-toggle-mute
    plate-wifi-status
    plate-wifi-toggle
    plate-wifi-configure
    plate-bluetooth-status
    plate-bluetooth-toggle
    (where-is-my-sddm-theme.override {
      themeConfig.General = {
        background = asahiPaths.wallpaper;
        backgroundMode = "fill";
        quote = "";
        accentColor = plate.accent.vermilion;
        passwordCursorColor = plate.accent.vermilion;
        font = plate.type.sddm;
        fontSize = 14;
        showSessionsByDefault = true;
      };
    })
  ];

  home-manager.backupFileExtension = "bk";
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    inherit asahiPaths;
  };
  home-manager.users.sspeaks = { ... }:
    {
      imports = [
        ../../home/sspeaks.nix
        ../../home/features/hyprland
        ../../home/features/hyprland/auto-brightness.nix
        ../../home/features/alacritty
        ../../home/features/ghostty
        ../../home/features/dunst
        ../../home/features/wofi
        ../../home/features/wlogout
        ../../home/features/fonts
        ./waybar.nix
        # Plate XIV compositor / shell — dormant until Trinity/Switch land the files.
        # builtins.pathExists avoids evaluation errors while agents run concurrently.
      ] ++ lib.optionals (builtins.pathExists ../../home/features/niri) [
        ../../home/features/niri
      ] ++ lib.optionals (builtins.pathExists ../../home/features/quickshell) [
        ../../home/features/quickshell
      ];
    };
}
