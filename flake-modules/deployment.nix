{
  perSystem = { pkgs, lib, ... }:
    let
      runtimeInputs = with pkgs; [
        bash
        git
        gh
        openssh
        coreutils
        gnused
        gnugrep
        jq
        curl
      ];

      deploy = pkgs.writeShellApplication {
        name = "deploy";
        inherit runtimeInputs;
        text = ''
          exec ${lib.getExe pkgs.bash} ${../scripts/deploy.sh} "$@"
        '';
      };

      update-fleet = pkgs.writeShellApplication {
        name = "update-fleet";
        inherit runtimeInputs;
        text = ''
          export FLEET_DEPLOY=${lib.getExe deploy}
          exec ${lib.getExe pkgs.bash} ${../scripts/update-fleet.sh} "$@"
        '';
      };
    in
    {
      packages = { inherit deploy update-fleet; };
      apps = {
        deploy = {
          type = "app";
          program = lib.getExe deploy;
          meta.description = "Deploy a reviewed cached NixOS closure with a rollback guard";
        };
        update-fleet = {
          type = "app";
          program = lib.getExe update-fleet;
          meta.description = "Update and inspect the NixOS fleet using CI-published closures";
        };
      };
    };
}
