{ pkgs, ... }:
let
  ptunnelPackage = import ./ptunnel.nix;
in
{
  systemd.services.ptunnelserver = {
    description = "pTunnel Server";
    serviceConfig = {
      ExecStart = "${ptunnelPackage}/bin/ptunnel -c eth0 -f \"/home/sspeaks/ptunnel.log\" -x \"P|pitone12\"";
      Restart = "always";
      RestartSec = 1;
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
  };

  systemd.services.ptunnelserver.enable = true;
}
