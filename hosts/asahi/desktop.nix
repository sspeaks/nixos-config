{ config, pkgs, lib, ... }:

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

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.dconf.enable = true;
  programs.hyprland.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
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
        background = "/var/lib/bing-wallpaper/wallpaper.jpg";
        backgroundMode = "fill";
        quote = "";
      };
    })
  ];

  home-manager.backupFileExtension = "bk";
  home-manager.useUserPackages = true;
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
