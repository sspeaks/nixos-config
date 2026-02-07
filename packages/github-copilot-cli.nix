{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (_: rec {
  version = "0.0.406-1";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-ez4u7A+H+goxV1Dvn8Bzd+J1sq5sH3X2GnGl6Lo4Gkk=";
  };
})
