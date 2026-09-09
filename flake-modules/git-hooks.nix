{
  perSystem = {
    pre-commit = {
      check.enable = true;
      settings.hooks = {
        treefmt.enable = true;

        # Reserve flake evaluation/build checks for pushes, not every commit.
        nix-flake-check = {
          enable = true;
          name = "nix flake check";
          entry = "nix flake check --no-eval-cache";
          language = "system";
          pass_filenames = false;
          always_run = true;
          # Show obsolescence warnings even when the check passes.
          verbose = true;
          stages = [ "pre-push" ];
        };
      };
    };
  };
}
