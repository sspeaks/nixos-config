{ config, pkgs, lib, inputs, ... }:
let pkgs-unstable = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform
.system};
in

{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix
    inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
    inputs.home-manager.nixosModules.home-manager
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  home-manager.backupFileExtension = "bk";
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;
  hardware.asahi.enable = true;
  hardware.asahi.setupAsahiSound = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  #hardware.asahi.useExperimentalGPUDriver = true;

  hardware.graphics = {
    package = pkgs-unstable.mesa;
  };
  hardware.bluetooth.enable = true;

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  };
  programs.waybar.enable = true;
  environment.systemPackages = with pkgs; [
    chromium
    iwgtk
    vscode
  ];

  networking = {
    hostName = "asahi-mpb";
  };

  services.openssh.enable = false;
  services.openssh.settings.X11Forwarding = false;

  # Docker
  virtualisation.docker.enable = true;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit inputs; };
  home-manager.users.sspeaks = { ... }:
    {
      imports = [
        ../../home/sspeaks.nix
        ../../home/features/hyprland
        ../../home/features/alacritty
        ../../home/features/dunst
        ../../home/features/wofi
        ../../home/features/wlogout
        ./waybar.nix
      ];
    };

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "America/Los_Angeles";

  nixpkgs.hostPlatform = "aarch64-linux";
}

