{ inputs, lib, config, ... }:
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/azure-common.nix"
  ];
  swapDevices = [{ device = "/swapfile"; size = 8192; }];
  networking = {
    hostName = ""; # Needs to be empty so we pull the hostname from azure
    enableIPv6 = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  myWireguard.enable = lib.mkDefault true;

  virtualisation.vmVariant = {
    networking.hostName = lib.mkForce "nixos-azure-local-vm";
    virtualisation.azure.agent.enable = lib.mkForce false;
    services.udev.extraRules = "";
    myWireguard.enable = false;
  };
}
