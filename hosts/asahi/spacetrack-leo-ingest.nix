{ config, pkgs, lib, ... }:

let
  enableService = false;
  spacetrackPgweb = pkgs.writeShellApplication {
    name = "spacetrack-pgweb";
    runtimeInputs = [
      pkgs.pgweb
      pkgs.sudo
    ];
    text = ''
      exec sudo -u spacetrack-ingest pgweb --readonly \
        --url 'postgres:///spacetrack-ingest?host=/run/postgresql&user=spacetrack-ingest&sslmode=disable' "$@"
    '';
  };
in
{
  # Do not decrypt service credentials while the service is disabled.
  sops.secrets = lib.mkIf enableService {
    spacetrack-username = {
      sopsFile = ../../secrets/asahi.yaml;
      owner = "spacetrack-ingest";
      group = "spacetrack-ingest";
      mode = "0400";
    };

    spacetrack-password = {
      sopsFile = ../../secrets/asahi.yaml;
      owner = "spacetrack-ingest";
      group = "spacetrack-ingest";
      mode = "0400";
    };
  };

  services.spacetrack-leo-ingest = {
    enable = enableService;

    # Avoid resolving paths to secrets that are disabled above.
    spacetrack.usernameFile = lib.mkIf enableService config.sops.secrets.spacetrack-username.path;
    spacetrack.passwordFile = lib.mkIf enableService config.sops.secrets.spacetrack-password.path;

    database.local = {
      enable = enableService;
      user = "spacetrack-ingest";
    };

    api.enable = enableService;
    api.openFirewall = enableService;

    notify = {
      enable = false;
    };

    conjunction = {
      enable = enableService;
      mode = "optimized";
      # Compacting GC avoids copying large propagation tables; cap heap growth.
      rtsOptions = [ "-N" "-c" "-M16g" ];
    };
  };

  environment.systemPackages = [
    pkgs.pgweb
    pkgs.postgresql
    spacetrackPgweb
  ];
}
