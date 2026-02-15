{ config, pkgs, lib, inputs, ... }:

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
  ];

  security.sudo.wheelNeedsPassword = false;

  # Zram swap - compresses RAM, better than disk swap on flash storage
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "America/Los_Angeles";
}

