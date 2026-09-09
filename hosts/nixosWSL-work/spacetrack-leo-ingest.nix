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
    sopsFile = ../../secrets/nixos-work.yaml;
    owner = "spacetrack-ingest";
    group = "spacetrack-ingest";
    mode = "0400";
  };

  sops.secrets.spacetrack-password = {
    sopsFile = ../../secrets/nixos-work.yaml;
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

    api.enable = true;
    api.openFirewall = true;

    notify = {
      enable = false;
    };

    conjunction = {
      enable = true;
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
