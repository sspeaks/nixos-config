{ inputs, outputs, pkgs, lib, config, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../sops.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = {
    inherit inputs outputs;
  };
  nixpkgs = {
    overlays = outputs.lib.overlayList;
    config = {
      allowUnfree = true;
    };
  };

  services.openssh.enable = lib.mkDefault true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  hardware.enableRedistributableFirmware = true;

  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.extra-substituters = [
    "https://sspeaks-nix.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "sspeaks-nix.cachix.org-1:Umjs3o8MgvHklkotM8S4XBfTz+zEQCnyr8TFpIC9x+o="
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "23.05";
}
