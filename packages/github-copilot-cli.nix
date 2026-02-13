{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (_: rec {
  version = "0.0.410-1";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-WzHoEnDALNjXnEwnh/3T94hu+QfNdLwiUAfuNwPl6d0=";
  };
})
