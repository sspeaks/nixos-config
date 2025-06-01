{ inputs, lib, ... }:
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/azure-common.nix"
  ];

  # These boot and filesystem items use to be included in azure-common and were removed for 25.05
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  boot.loader.grub.device = "/dev/sda";

  boot.growPartition = true;


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
