{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (_: rec {
  version = "0.0.409";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-JcnZesLHH1LFtAE91Dzx0t4cGYj/j3ifDtSrAcvaw0s=";
  };
})
