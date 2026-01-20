{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;

  services.xserver.displayManager.sddm.enable = true;
  services.xserver.displayManager.sddm.wayland.enable = true;


  programs.hyprland.enable = true;

  virtualisation.qemu.options = [
    "-device virtio-vga"
  ];

  users.users.sspeaks = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "test";
  };

  home-manager.extraSpecialArgs = {
    inherit inputs;
  };
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks.nix ];
    wayland.windowManager.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      settings = {
        bind = [
          "CTRL,Q,exec,kitty"
        ];
      };
      #      xwayland.enable = true;

    };
  };

  pkgs.stdenv.hostPlatform.system.stateVersion = "24.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
