{ config, pkgs, lib, inputs, ... }:

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

  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;
  hardware.asahi.enable = true;
  hardware.asahi.setupAsahiSound = true;

  hardware.asahi.useExperimentalGPUDriver = true;

  programs.hyprland.enable = true;
  programs.waybar.enable = true;
  sound.enable = true;
  environment.systemPackages = with pkgs; [
    firefox
    kitty
  ];

  networking = {
    hostName = "asahi-mpb";
  };

  services.openssh.enable = false;
  services.openssh.settings.X11Forwarding = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }:
    {
      imports = [
        ../../home/sspeaks.nix
        #      ./waybar.nix
      ];
    };

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "America/Los_Angeles";

  nixpkgs.hostPlatform = "aarch64-linux";
}

