{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (_: rec {
  version = "0.0.407-1";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-h3XBvWHwS6lbHMjCwvUPZiIo9Ss6pMHtTSR5h03S4Ls=";
  };
})
