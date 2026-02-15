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
          (old.configureFlags or []);
      });
    })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;
  hardware.asahi.enable = true;
  hardware.asahi.setupAsahiSound = true;

  hardware.graphics.enable = true;

  nixpkgs.hostPlatform = "aarch64-linux";
}
