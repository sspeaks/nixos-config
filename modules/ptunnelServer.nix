{ pkgs, lib,config, ... }:
let cfg = config.services.ptunnServer;
    iN = v: v != null;
in
{
  options.services.ptunnServer = {
    enable = lib.mkEnableOption "Should enable ptunnel server";
    interface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
    };
    logDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    password = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;

    };
  };
  config = lib.mkIf cfg.enable {
  systemd.services.ptunnelserver = {
    description = "pTunnel Server";
    serviceConfig = {
      ExecStart = "${pkgs.ptunn}/bin/ptunnel" 
        + lib.optionalString (iN cfg.interface) " -c ${cfg.interface}"
        + lib.optionalString (iN cfg.logDir) " -f \"${cfg.logDir}\""
        + lib.optionalString (iN cfg.password) " -x \"${cfg.password}\"";
      Restart = "always";
      RestartSec = 1;
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
  };

  systemd.services.ptunnelserver.enable = true;
};
}
