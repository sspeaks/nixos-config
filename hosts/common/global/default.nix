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

  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkDefault "no";
      X11Forwarding = lib.mkDefault false;
    };
  };

  hardware.enableRedistributableFirmware = true;

  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.extra-substituters = [
    "https://sspeaks-nix.cachix.org"
    "https://nixos-raspberrypi.cachix.org"
    "https://nixos-apple-silicon.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "sspeaks-nix.cachix.org-1:Umjs3o8MgvHklkotM8S4XBfTz+zEQCnyr8TFpIC9x+o="
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  services.journald.extraConfig = ''
    SystemMaxUse=512M
    SystemKeepFree=256M
    SystemMaxFileSize=64M
    MaxRetentionSec=90d
    Compress=yes
  '';

  boot.tmp.cleanOnBoot = true;

  system.stateVersion = "23.05";
}
