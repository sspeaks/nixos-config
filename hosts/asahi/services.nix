{ config, pkgs, lib, ... }:

{
  services.logind.settings.Login.HandleLidSwitch = "suspend";
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";
  services.logind.settings.Login.HandleLidSwitchExternalPower = "lock";

  services.openssh.enable = false;
  services.openssh.settings.X11Forwarding = false;

  # Docker
  virtualisation.docker.enable = true;

  # Keyring - auto-unlocks at login for Chromium, git, etc.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Power management
  services.power-profiles-daemon.enable = true;
}
