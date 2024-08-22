{ inputs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-5
  ];
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
  swapDevices = [{ device = "/swapfile"; size = 4096; }];
}
