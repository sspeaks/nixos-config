{ config, pkgs, lib, ... }:

{
  services.logind.settings.Login.HandleLidSwitch = "suspend";
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";
  services.logind.settings.Login.HandleLidSwitchExternalPower = "lock";

  services.openssh.enable = false;
  services.openssh.settings.X11Forwarding = false;

  virtualisation.docker.enable = true;
  users.users.sspeaks.extraGroups = [ "docker" ];

  # Unlock the application keyring through SDDM's PAM session.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  services.power-profiles-daemon.enable = true;
}
