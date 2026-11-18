{
  perSystem = {
    pre-commit = {
      check.enable = true;
      # `nix flake check` runs in CI (.github/workflows/check.yml) and on demand
      # via the devshell `check` command; it is too slow for a pre-push hook.
      settings.hooks.treefmt.enable = true;
    };
  };
}
