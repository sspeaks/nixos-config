{ config, pkgs, lib, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;  # Required for BLE FIDO2/passkey (caBLE hybrid transport)
        KernelExperimental = true;  # Enable kernel-level BLE experimental features
      };
    };
  };

  # Blueman service (provides root-level D-Bus mechanism for blueman-applet)
  services.blueman.enable = true;

  # Allow non-root access to /dev/uhid (required for FIDO2/passkey caBLE hybrid transport)
  services.udev.extraRules = ''
    KERNEL=="uhid", GROUP="input", MODE="0660"
  '';
}
