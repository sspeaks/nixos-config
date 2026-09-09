{ config, pkgs, lib, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true; # Required for BLE FIDO2/passkey (caBLE hybrid transport)
        KernelExperimental = true;
      };
    };
  };

  # Provide the privileged D-Bus backend for blueman-applet.
  services.blueman.enable = true;

  # Passkey caBLE transport needs non-root /dev/uhid access.
  services.udev.extraRules = ''
    KERNEL=="uhid", GROUP="input", MODE="0660"
  '';
}
