{ pkgs, lib, config, ... }:
let
  cfg = config.services.udp2rawServer;
  helpers = import ../lib { inherit lib; };
  inherit (helpers) isNotNull;
in
{
  options.services.udp2rawServer = {
    enable = lib.mkEnableOption "Should enable udp2raw server";
    localAddressAndPort = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    remoteAddressAndPort = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    autoAddIpTablesRules = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    rawMode = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    logLevel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    password = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;

    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.udp2rawserver = {
      description = "udp2raw Server";
      serviceConfig = {
        ExecStart = "${pkgs.udp2raw}/bin/udp2raw -s"
          + lib.optionalString (isNotNull cfg.localAddressAndPort) " -l ${cfg.localAddressAndPort}"
          + lib.optionalString (isNotNull cfg.remoteAddressAndPort) " -r ${cfg.remoteAddressAndPort}"
          + lib.optionalString (isNotNull cfg.password) " -k \"${cfg.password}\""
          + lib.optionalString (isNotNull cfg.rawMode) " --raw-mode ${cfg.rawMode}"
          + lib.optionalString (cfg.autoAddIpTablesRules) " -a"
          + lib.optionalString (isNotNull cfg.logLevel) " --log-level ${cfg.logLevel}";
        Restart = "always";
        RestartSec = 1;
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
    };
  };
}
