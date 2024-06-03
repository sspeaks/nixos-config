{ pkgs, ... }:
let
  ptunnelPackage = import ./default.nix;
in
{
  systemd.services.ptunnelserver = {
    description = "pTunnel Server";
    serviceConfig = {
      ExecStart = "${ptunnelPackage}/bin/udp2raw -s -l 0.0.0.0:25565 -r 127.0.0.1:51820 -k \"password\" --raw-mode icmp -a --log-level 5";
      Restart = "always";
      RestartSec = 1;
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
  };

  systemd.services.ptunnelserver.enable = true;
}
