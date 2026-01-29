{ pkgs, lib, config, ... }:
let
  cfg = config.services.udp2rawServer;
  helpers = import ./lib { inherit lib; };
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
      description = ''
        Password for udp2raw server authentication.
        WARNING: This will be visible in the Nix store and process listings.
        
        For better security, use sops-nix with systemd LoadCredential:
        1. Store password in sops-encrypted secrets file
        2. Add to sops secrets: `sops.secrets."udp2raw-password" = {};`
        3. Use LoadCredential: `LoadCredential = "password:''${config.sops.secrets."udp2raw-password".path}";`
        4. Modify ExecStart to read from: `$CREDENTIALS_DIRECTORY/password`
        5. Or create wrapper script: `ExecStart = pkgs.writeShellScript "udp2raw-start" ''
           PASSWORD=$(cat $CREDENTIALS_DIRECTORY/password)
           exec ${pkgs.udp2raw}/bin/udp2raw -s ... -k "$PASSWORD"
        ''`
      '';
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
      # wantedBy automatically enables the service - no need for explicit enable = true
      # When a service is "wanted by" a target, systemd activates it when that target is reached
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
    };
  };
}
