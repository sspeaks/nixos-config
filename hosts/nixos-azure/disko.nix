{ ... }:
# UEFI disk layout and bootloader for nixos-azure: a GPT disk with an EFI
# System Partition and systemd-boot, for deploying to a UEFI (Gen2) Azure VM.
#
# Injected only into the nixos-azure nixosConfiguration via extraModules in
# flake-modules/hosts.nix (not imported by default.nix), so hosts that import
# ../nixos-azure do not inherit disko or the UEFI bootloader.
{
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            # Keep the "nixos" label for parity with the previous config.
            extraArgs = [ "-L" "nixos" ];
          };
        };
      };
    };
  };
}
