{ config, pkgs, inputs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;

  services.xserver.displayManager.gdm.enable = true;
  programs.sway.enable = true;

  #  imports = [ "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
  #  virtualisation.qemu.options = [
  #    "-device virtio-vga"
  #  ];

  users.users.sspeaks = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "test";
  };

  system.stateVersion = "23.11";
  nixpkgs.hostPlatform = "x86_64-linux";
}
