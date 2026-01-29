{ pkgs, lib, config, ... }:
let
  cfg = config.services.ptunnServer;
  helpers = import ../lib { inherit lib; };
  inherit (helpers) isNotNull;
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
      description = ''
        Password for ptunnel server authentication.
        WARNING: This will be visible in the Nix store and process listings.
        Consider using sops-nix or another secret management solution for production use.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.ptunnelserver = {
      description = "pTunnel Server";
      serviceConfig = {
        ExecStart = "${pkgs.ptunn}/bin/ptunnel"
          + lib.optionalString (isNotNull cfg.interface) " -c ${cfg.interface}"
          + lib.optionalString (isNotNull cfg.logDir) " -f \"${cfg.logDir}\""
          + lib.optionalString (isNotNull cfg.password) " -x \"${cfg.password}\"";
        Restart = "always";
        RestartSec = 1;
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
    };
  };
}
