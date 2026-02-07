{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (_: rec {
  version = "0.0.405";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-j6c6/80r0gvw3JYs3MuaBQIWWIEHIazGIJrUFADzuMA=";
  };
})
