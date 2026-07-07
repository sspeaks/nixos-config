{ ... }:
# BIOS disk layout and bootloader for pogbot (grub on /dev/sda, root labeled
# "nixos"). Kept here rather than in the shared ../nixos-azure config so that
# pogbot's boot setup is independent of nixos-azure's disk configuration.
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  boot.loader.grub.device = "/dev/sda";
  boot.growPartition = true;
}
