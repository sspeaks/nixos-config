{
  perSystem = { pkgs, lib, ... }: {
    checks = {
      deployment = pkgs.runCommand "deployment-regressions"
        {
          nativeBuildInputs = with pkgs; [
            bash
            coreutils
            git
            gawk
            gnused
            gnugrep
            jq
            python3
          ];
        }
        ''
          bash ${../tests}/update-fleet.sh ${../scripts/update-fleet.sh}
          bash ${../tests}/deploy.sh ${../scripts/deploy.sh}
          touch "$out"
        '';
    } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      # Two-path fixture for incomplete-cache rejection on Linux targets. Remove
      # the leaf's NAR and .narinfo to test a missing runtime reference. Unique
      # names and contents prevent public caches from satisfying that reference.
      nix-copy-fixture =
        let
          marker = "incomplete-cache-nix-copy-fixture-20260902";

          leaf = pkgs.runCommand "${marker}-leaf" { } ''
            mkdir -p "$out"
            echo "${marker}: leaf payload" > "$out/leaf.txt"
          '';
        in
        pkgs.runCommand "${marker}-top" { } ''
          mkdir -p "$out"
          echo "${marker}: top payload" > "$out/top.txt"
          # A real runtime reference keeps the closure at two paths.
          ln -s ${leaf} "$out/leaf"
        '';
    };
  };
}
