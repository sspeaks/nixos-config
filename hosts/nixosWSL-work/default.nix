{ config, pkgs, lib, inputs, ... }:

let

in
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix
    inputs.nixos-wsl.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];

  wsl.enable = true;
  wsl.defaultUser = "sspeaks";

  networking = {
    hostName = "NixOS-WSL-work";
  };

  services.openssh.enable = false;
  services.openssh.settings.X11Forwarding = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = ../../home/sspeaks.nix;

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "America/Los_Angeles";

  nixpkgs.hostPlatform = "x86_64-linux";
}

