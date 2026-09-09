{ config, pkgs, lib, inputs, ... }:

let
  asahiPaths = import ./paths.nix { inherit pkgs; };
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
  ];

  _module.args = {
    inherit asahiPaths;
  };

  # Support cross-platform builds through emulation.
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

  security.sudo.wheelNeedsPassword = false;

  # Use compressed RAM to reduce flash-backed swap writes.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "America/Los_Angeles";
}
