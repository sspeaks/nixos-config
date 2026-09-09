{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
  ];

  # Optional jemalloc workaround: auto-detect page size for 16 KiB Asahi kernels.
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     jemalloc = prev.jemalloc.overrideAttrs (old: {
  #       configureFlags = builtins.filter
  #         (f: builtins.match ".*--with-lg-page=.*" f == null)
  #         (old.configureFlags or [ ]);
  #     });
  #   })
  # ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  # The support module expects firmware.cpio, not the installer's tarball.
  # Convert the bundled firmware with asahi-fwextract.
  hardware.asahi.peripheralFirmwareDirectory =
    pkgs.runCommand "asahi-peripheral-firmware-cpio"
      { nativeBuildInputs = [ config.hardware.asahi.pkgs.asahi-fwextract ]; }
      ''
        mkdir -p $out
        asahi-fwextract ${./firmware} $out
      '';
  hardware.asahi.enable = true;
  hardware.asahi.setupAsahiSound = true;

  hardware.graphics.enable = true;

  nixpkgs.hostPlatform = "aarch64-linux";
}
