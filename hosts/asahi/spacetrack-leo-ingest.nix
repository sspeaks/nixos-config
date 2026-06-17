{ config, pkgs, ... }:

let
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
    owner = "spacetrack-ingest";
    group = "spacetrack-ingest";
    mode = "0400";
  };

  sops.secrets.spacetrack-password = {
    sopsFile = ../../secrets/asahi.yaml;
    owner = "spacetrack-ingest";
    group = "spacetrack-ingest";
    mode = "0400";
  };

  services.spacetrack-leo-ingest = {
    enable = true;

    spacetrack.usernameFile = config.sops.secrets.spacetrack-username.path;
    spacetrack.passwordFile = config.sops.secrets.spacetrack-password.path;

    database.local = {
      enable = true;
      user = "spacetrack-ingest";
    };

    conjunction = {
      enable = true;
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
