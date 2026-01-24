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
    let
      customAuthentikScope = inputs.authentik-nix.lib.mkAuthentikScope {
        inherit pkgs;
      };

      # Override the scope to change gopkgs
      overriddenScope = customAuthentikScope.overrideScope (
        final: prev: {
          authentikComponents = prev.authentikComponents // {
            gopkgs = prev.authentikComponents.gopkgs.override {
              buildGo124Module = pkgs.buildGo125Module;
            };
          };
        }
      );
    in
    {
      enable = true;
      environmentFile = config.sops.secrets.AUTHENTIK_ENV.path;
      # nginx.enable = true;
      # nginx.host = "authentik.bs.home";


      inherit (overriddenScope) authentikComponents;
    };
    networking.firewall.allowedTCPPorts = [9443 9000 9001];
}
