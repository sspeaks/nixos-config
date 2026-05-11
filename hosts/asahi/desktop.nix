{ config, pkgs, lib, asahiPaths, ... }:

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
  services.displayManager.defaultSession = "hyprland";

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.dconf.enable = true;
  programs.hyprland.enable = true;

  # Remove the uwsm session file — it fails without uwsm units installed
  services.displayManager.sessionPackages = lib.mkForce [
    (pkgs.runCommand "hyprland-sessions"
      {
        passthru.providedSessions = [ "hyprland" ];
      } ''
      mkdir -p $out/share/wayland-sessions
      cp ${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop $out/share/wayland-sessions/
    '')
  ];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    chromium
    vlc
    iwgtk
    vscode
    gnumake
    (where-is-my-sddm-theme.override {
      themeConfig.General = {
        background = asahiPaths.wallpaper;
        backgroundMode = "fill";
        quote = "";
        accentColor = "#89b4fa";
        font = "JetBrains Mono";
        fontSize = 14;
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
        ../../home/features/dunst
        ../../home/features/wofi
        ../../home/features/wlogout
        ../../home/features/fonts
        ./waybar.nix
      ];
    };
}
