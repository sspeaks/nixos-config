{ config, pkgs, inputs, outputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  nixpkgs.overlays = outputs.lib.overlayList;
  nixpkgs.config.allowUnfree = true;

  users.users.sspeaks = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "test";
  };

  home-manager.extraSpecialArgs = {
    inherit inputs outputs;
  };
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks.nix ];
  };

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/vda";

  system.stateVersion = "25.11";
  nixpkgs.hostPlatform = "x86_64-linux";
}
