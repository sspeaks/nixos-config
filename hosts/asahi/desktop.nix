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

  # Keep Hyprland selectable as a fallback to niri. Copy only its standalone
  # desktop entry: the uwsm variant cannot start without uwsm units.
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

  # Own portal routing here, not in Home Manager. Use each compositor's
  # capture backend; niri's niri-portals.conf prefers GNOME, not wlr.
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

  # Quickshell's battery display requires UPower.
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
    # The greeter must resolve Exec=niri-session before Home Manager activation.
    niri
    # Compositor-aware DPMS and logout; see packages/plate-wrappers.
    plate-dpms-on
    plate-dpms-off
    plate-logout
    # Put Quickshell's control helpers on the system PATH so Process calls
    # do not depend on Home Manager activation order.
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
    plate-screenshot
    plate-ocr
    plate-nightlight-toggle
    plate-record-start
    plate-record-stop
    plate-record-toggle
    plate-shutdown
    plate-reboot
    # plate-record-* uses software encoding (libx264); apple-dcp has no VAAPI.
    wf-recorder
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
      ] ++ lib.optionals (builtins.pathExists ../../home/features/niri) [
        ../../home/features/niri
      ] ++ lib.optionals (builtins.pathExists ../../home/features/quickshell) [
        ../../home/features/quickshell
      ] ++ lib.optionals (builtins.pathExists ../../home/features/nightlight) [
        ../../home/features/nightlight
      ];
    };
}
