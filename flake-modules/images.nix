{ self, ... }:
{
  perSystem = { system, lib, ... }: {
    # Bootable installation images.
    #
    # These exist because a `system.build.toplevel` closure is neither an Azure
    # Gen2 VHD nor a bootable Pi SD card. Keep the real artifacts as first-class
    # flake outputs so they can be reproduced and inspected without depending
    # on a retired Azure build VM or assembling them ad hoc in CI.
    packages = lib.optionalAttrs (system == "aarch64-linux") {
      # Fixed-size Gen2 VHD. `system.build.azureImage` runs
      # `qemu-img convert -o subformat=fixed,force_size -O vpc`; Azure rejects
      # dynamic VHDs at disk-create time.
      proxyAzureImage = self.nixosConfigurations.proxy.config.system.build.azureImage;

      # Real bootable SD image for the Time Machine Pi, not a toplevel closure.
      raspberrytimemachineImage =
        self.nixosConfigurations.raspberrytimemachine.config.system.build.sdImage;
    };
  };
}
