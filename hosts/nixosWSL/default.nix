{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix
    inputs.nixos-wsl.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.determinate.nixosModules.default
  ];

  wsl.enable = true;
  wsl.defaultUser = "sspeaks";

  nix.settings.lazy-trees = true;

  networking = {
    hostName = "NixOS-WSL";
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

