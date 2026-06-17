{ config, pkgs, lib, inputs, ... }:

let
  asahiPaths = import ./paths.nix;
in
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix
    ./hardware.nix
    ./networking.nix
    ./desktop.nix
    ./bluetooth.nix
    ./services.nix
    inputs.haskell-conjunction.nixosModules.spacetrack-leo-ingest
    ./spacetrack-leo-ingest.nix
    ./bing-wallpaper.nix
  ];

  _module.args = {
    inherit asahiPaths;
  };

  # Enable x86_64 emulation via QEMU for cross-platform builds
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

  security.sudo.wheelNeedsPassword = false;

  # Zram swap - compresses RAM, better than disk swap on flash storage
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "America/Los_Angeles";
}

