{ inputs, lib, ... }:
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/azure-common.nix"
  ];

  # Disk layout and bootloader are defined per-host, not here (this file is
  # shared: pogbot imports ../nixos-azure). nixos-azure uses ./disko.nix
  # (injected via flake-modules/hosts.nix); pogbot uses ../pogbot/disk-boot.nix.

  swapDevices = [{ device = "/swapfile"; size = 8192; }];
  networking = {
    hostName = ""; # Needs to be empty so we pull the hostname from azure
    enableIPv6 = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  virtualisation.vmVariant = {
    networking.hostName = lib.mkForce "nixos-azure-local-vm";
    disabledModules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/azure-common.nix"
    ];
    users.users.sspeaks.initialPassword = "test";
    users.users.sspeaks.hashedPassword = lib.mkForce null;
    users.users.sspeaks.hashedPasswordFile = lib.mkForce null;
    services.udev.extraRules = "";
  };
}
