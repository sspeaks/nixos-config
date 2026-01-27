{ pkgs, config, ... }:
{
  networking.firewall.allowedTCPPorts = [ 8123 ];
  services.home-assistant = {
    enable = true;
    customComponents = [
      (config.services.home-assistant.package.python.pkgs.callPackage ./hass-openid.nix { })
    ];
    config = null;
    configDir = "/etc/home-assistant";

  };
}
