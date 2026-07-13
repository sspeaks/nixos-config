{
  perSystem = {
    pre-commit = {
      check.enable = true;
      settings.hooks = {
        treefmt.enable = true;

        # Run `nix flake check` on `git push` (not on every commit). Evaluates
        # all host configs + builds the flake `checks` (treefmt, pre-commit).
        nix-flake-check = {
          enable = true;
          name = "nix flake check";
          entry = "nix flake check";
          language = "system";
          pass_filenames = false;
          always_run = true;
          # pre-commit hides a passing hook's output; without this the
          # obsolescence warnings emitted by a successful check are swallowed.
          verbose = true;
          stages = [ "pre-push" ];
        };
      };
    };
  };
}
