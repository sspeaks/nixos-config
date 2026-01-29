{ pkgs, lib, config, ... }:
let
  cfg = config.services.ptunnServer;
  helpers = import ./lib { inherit lib; };
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
        
        For better security, use sops-nix with systemd LoadCredential:
        1. Store password in sops-encrypted secrets file
        2. Add to sops secrets: `sops.secrets."ptunnel-password" = {};`
        3. Use LoadCredential: `LoadCredential = "password:''${config.sops.secrets."ptunnel-password".path}";`
        4. Modify ExecStart to read from: `$CREDENTIALS_DIRECTORY/password`
        5. Or create wrapper script: `ExecStart = pkgs.writeShellScript "ptunnel-start" ''
           PASSWORD=$(cat $CREDENTIALS_DIRECTORY/password)
           exec ${pkgs.ptunn}/bin/ptunnel -c ${cfg.interface} ... -x "$PASSWORD"
        ''`
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.ptunnelserver = {
      description = "pTunnel Server";
      serviceConfig = {
        ExecStart = "${pkgs.ptunn}/bin/ptunnel -c ${cfg.interface}"
          + lib.optionalString (isNotNull cfg.logDir) " -f \"${cfg.logDir}\""
          + lib.optionalString (isNotNull cfg.password) " -x \"${cfg.password}\"";
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
