{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (old: rec {
  version = "0.0.410";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-oJEerl0LHn8EO3KUqt0jz5Fmm8EOX/+3LRF1tf6L2Yk=";
  };
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@github/copilot
    cp -r . $out/lib/node_modules/@github/copilot

    mkdir -p $out/bin
    makeBinaryWrapper ${pkgs.nodejs}/bin/node $out/bin/copilot \
      --add-flags "$out/lib/node_modules/@github/copilot/index.js" \
      --set SSL_CERT_DIR "${pkgs.cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    runHook postInstall
  '';
})
