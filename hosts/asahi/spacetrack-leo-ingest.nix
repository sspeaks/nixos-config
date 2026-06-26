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
  # Only define (and therefore decrypt) the sops secrets when the service is
  # enabled. With enableService = false this is mkIf false, so the secrets are
  # never decrypted.
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

    # Guarded by mkIf so config.sops.secrets.*.path is never forced when the
    # service (and thus the secrets above) is disabled.
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
      # Compacting GC (-c) keeps the per-tile propagation table from doubling at
      # major GC; -N uses all cores. -M16g is a safety ceiling: the tiled screen
      # peaks around 6 GB, so a runaway fails as a clean heap overflow instead of
      # driving this 22 GB host into the OOM killer.
      rtsOptions = [ "-N" "-c" "-M16g" ];
    };
  };

  environment.systemPackages = [
    pkgs.pgweb
    pkgs.postgresql
    spacetrackPgweb
  ];
}
