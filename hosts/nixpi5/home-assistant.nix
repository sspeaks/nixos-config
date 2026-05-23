{ pkgs, config, ... }:
{
  networking.firewall.allowedTCPPorts = [ 8123 ];
  services.home-assistant = {
    enable = true;
    customComponents = [
      (config.services.home-assistant.package.python.pkgs.callPackage ./hass-openid.nix { })
    ];
    extraComponents = [ "default_config" "onvif" ];
    config = null;
    configDir = "/etc/home-assistant";

  };

  systemd.services.home-assistant = {
    after = [ "authentik.service" "go2rtc.service" ];
    wants = [ "authentik.service" "go2rtc.service" ];
  };
}
