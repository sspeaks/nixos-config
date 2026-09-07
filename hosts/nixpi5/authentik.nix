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
      # nginx.enable = true;
      # nginx.host = "authentik.bs.home";


    };

  # PostgreSQL 16, overriding authentik-nix's legacy pin.
  #
  # authentik-nix sets `services.postgresql.package = mkOverride 999
  # pkgs.postgresql_14` for any host whose stateVersion is older than 24.05, and
  # this one is 23.05. That is a COMPATIBILITY measure, not a requirement. The
  # module's own comment says the intent is that "new installations use the
  # sensible default provided by nixpkgs" and that affected hosts "would need to
  # override the postgresql package in their own config". This is that override:
  # a normal definition sits at priority 100 and so beats mkOverride 999.
  #
  # PostgreSQL 14 reaches end of life on 2026-11-12. 16 is chosen over 17 or 18
  # to match vidbox, keeping a single postgres major across the estate, and is
  # itself supported until November 2028.
  #
  # services.postgresql.dataDir tracks the major version, so this does NOT
  # upgrade in place: it initialises a fresh cluster at /var/lib/postgresql/16
  # and leaves /var/lib/postgresql/14 completely untouched. That directory is
  # the rollback -- revert this one line and the old cluster is still there,
  # intact. The data itself moves by dump and restore, which is the right
  # mechanism at 130 MB and avoids pg_upgrade entirely.
  #
  # Note that authentik-migrate will run Django migrations against the new,
  # empty database on first boot. The restore therefore drops and recreates the
  # database rather than restoring over that fresh schema.
  services.postgresql.package = pkgs.postgresql_16;
  networking.firewall.allowedTCPPorts = [ 9443 9000 9001 ];
}
