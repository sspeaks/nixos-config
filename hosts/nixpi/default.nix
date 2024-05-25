{ config, pkgs, lib, inputs, ... }:

let

in
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.vscode-server.nixosModules.default
  ];

  networking = {
    hostName = "nixpi";
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = {...} : {
    imports = [../../home/sspeaks.nix ];
    programs.starship.settings.hostname.disabled = false;
  };

  services.vscode-server.enable = true;
  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "America/Los_Angeles";

  nixpkgs.hostPlatform = "aarch64-linux";
}

