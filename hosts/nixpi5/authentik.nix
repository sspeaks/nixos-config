{ inputs, pkgs, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi5.yaml;
  };
in
{

  imports = [ inputs.authentik-nix.nixosModules.default ];

  sops.secrets = {
    AUTHENTIK_ENV = sopsFileLocation;
  };


  services.authentik =
    {
      enable = true;
      environmentFile = config.sops.secrets.AUTHENTIK_ENV.path;


    };

  # Override authentik-nix's stateVersion-based PostgreSQL 14 pin.
  # Major versions use separate data directories; this is not a data migration.
  # Migrate by dump/restore, recreating the database before restoring if
  # Authentik has already initialized its schema.
  services.postgresql.package = pkgs.postgresql_16;
  networking.firewall.allowedTCPPorts = [ 9443 9000 9001 ];
}
