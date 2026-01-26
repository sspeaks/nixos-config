{ inputs, pkgs, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ./secrets.yaml;
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
  networking.firewall.allowedTCPPorts = [ 9443 9000 9001 ];
}
