{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
  ];

  # Let jemalloc auto-detect page size at build time (fixes 16K page Asahi kernels)
  nixpkgs.overlays = [
    (final: prev: {
      jemalloc = prev.jemalloc.overrideAttrs (old: {
        configureFlags = builtins.filter
          (f: builtins.match ".*--with-lg-page=.*" f == null)
          (old.configureFlags or [ ]);
      });
    })
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;
  hardware.asahi.enable = true;
  hardware.asahi.setupAsahiSound = true;

  hardware.graphics.enable = true;

  # Workaround: Asahi uses 16K pages but nixpkgs mis-detects page size (nixos-apple-silicon#449).
  # The upstream fix (nixpkgs#513687) sets this to 31 for ARM64_16K_PAGES; remove once landed in nixos-unstable.
  boot.kernel.sysctl."vm.mmap_rnd_bits" = 31;

  nixpkgs.hostPlatform = "aarch64-linux";
}
