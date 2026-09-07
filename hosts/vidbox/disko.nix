{ ... }:
# Disk layout and bootloader for `vidbox`, the home Hyper-V VM that takes over
# vid-stream's workload.
#
# Uses the same layout as a Gen2 Azure guest: an Azure VM IS a Hyper-V VM,
# so the guest presents the same way -- a Gen2/UEFI machine with its
# boot disk on the SCSI controller at /dev/sda. Both were verified on the live
# installer before this was written: /sys/firmware/efi exists, and lsblk shows a
# single 512 G sda.
#
# Injected only into the `vidbox` nixosConfiguration via extraModules in
# flake-modules/hosts.nix, so nothing importing this host inherits disko or the
# bootloader choice.
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
            extraArgs = [ "-L" "vidbox" ];
          };
        };
      };
    };
  };
}
