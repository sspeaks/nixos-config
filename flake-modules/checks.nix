{ inputs, ... }:
{
  perSystem = { pkgs, lib, ... }:
    let
      taskwikiHome = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ../home/features/neovim
          ../home/features/taskwiki
          {
            home.username = "taskwiki-test";
            home.homeDirectory = "/home/taskwiki-test";
            home.stateVersion = "23.05";
          }
        ];
      };
      taskwikiConfig = taskwikiHome.config;
    in
    {
      checks = {
        taskwiki = pkgs.runCommand "taskwiki-regressions"
          { nativeBuildInputs = with pkgs; [ bash coreutils python3 ]; }
          ''
            bash ${../tests/taskwiki.sh} \
              ${taskwikiConfig.programs.nixvim.build.package}/bin/nvim \
              ${taskwikiConfig.programs.nixvim.build.initFile} \
              ${lib.getExe taskwikiConfig.programs.taskwarrior.package} \
              ${lib.getExe pkgs.taskopen} \
              ${taskwikiConfig.xdg.configFile."taskopen/taskopenrc".source} \
              ${taskwikiConfig.home.file."/home/taskwiki-test/.config/task/home-manager-taskrc".source}
            touch "$out"
          '';

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
            bash ${../tests}/update-fleet.sh ${../scripts/update-fleet.sh} ${../.github/workflows/host-build-cache.yml}
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
