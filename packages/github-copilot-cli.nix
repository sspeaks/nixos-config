{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (_: rec {
  version = "0.0.410";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-oJEerl0LHn8EO3KUqt0jz5Fmm8EOX/+3LRF1tf6L2Yk=";
  };
})
