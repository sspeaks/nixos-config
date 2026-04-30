{
  perSystem = { config, ... }: {
    treefmt = {
      inherit (config.flake-root) projectRootFile;
      programs.nixpkgs-fmt.enable = true;
    };
  };
}
