{ config, pkgs, ... }:

let
  # Single source of truth: the module only creates the spacetrack-ingest
  # user/group when the service is enabled, so the sops secrets must fall back
  # to root ownership when it is off (otherwise sops-install-secrets fails to
  # chown to a non-existent user during activation).
  ingestEnable = false;
  secretOwner = if ingestEnable then "spacetrack-ingest" else "root";

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
  sops.secrets.spacetrack-username = {
    sopsFile = ../../secrets/asahi.yaml;
    owner = secretOwner;
    group = secretOwner;
    mode = "0400";
  };

  sops.secrets.spacetrack-password = {
    sopsFile = ../../secrets/asahi.yaml;
    owner = secretOwner;
    group = secretOwner;
    mode = "0400";
  };

  services.spacetrack-leo-ingest = {
    enable = ingestEnable;

    spacetrack.usernameFile = config.sops.secrets.spacetrack-username.path;
    spacetrack.passwordFile = config.sops.secrets.spacetrack-password.path;

    database.local = {
      enable = false;
      user = "spacetrack-ingest";
    };

    conjunction = {
      enable = false;
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
