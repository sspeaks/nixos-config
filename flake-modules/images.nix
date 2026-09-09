{ self, ... }:
{
  perSystem = { system, lib, ... }: {
    # Installation media are separate from system.build.toplevel closures.
    packages = lib.optionalAttrs (system == "aarch64-linux") {
      # Azure requires a fixed-size Gen2 VHD, not a dynamic VHD.
      proxyAzureImage = self.nixosConfigurations.proxy.config.system.build.azureImage;

      raspberrytimemachineImage =
        self.nixosConfigurations.raspberrytimemachine.config.system.build.sdImage;
    };
  };
}
