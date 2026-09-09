{ self, ... }:
{
  perSystem = { system, lib, ... }: {
    # P2.1 executable image outputs.
    #
    # These exist because a `system.build.toplevel` closure is neither an Azure
    # Gen2 VHD nor a bootable Pi SD card. The migration plan requires the real
    # artifacts to be produced and inspected before the only known ARM builder
    # (`nixos-aarch64-linux`) is deleted, so they are first-class flake outputs
    # rather than something assembled ad hoc in CI.
    packages = lib.optionalAttrs (system == "aarch64-linux") {
      # Fixed-size Gen2 VHD. `system.build.azureImage` runs
      # `qemu-img convert -o subformat=fixed,force_size -O vpc`; Azure rejects
      # dynamic VHDs at disk-create time.
      proxyAzureImage = self.nixosConfigurations.proxy.config.system.build.azureImage;

      # Real bootable SD image for `.106`, not a toplevel closure.
      raspberrytimemachineImage =
        self.nixosConfigurations.raspberrytimemachine.config.system.build.sdImage;
    };
  };
}
