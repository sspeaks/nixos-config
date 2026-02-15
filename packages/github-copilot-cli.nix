{ pkgs, fetchzip }:
pkgs.github-copilot-cli.overrideAttrs (old: rec {
  version = "0.0.410";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-oJEerl0LHn8EO3KUqt0jz5Fmm8EOX/+3LRF1tf6L2Yk=";
  };
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@github/copilot
    cp -r . $out/lib/node_modules/@github/copilot

    # Replace bundled rg (statically links jemalloc built for 4K pages) with system ripgrep
    rm -rf $out/lib/node_modules/@github/copilot/ripgrep/bin
    mkdir -p $out/lib/node_modules/@github/copilot/ripgrep/bin/linux-arm64
    ln -s ${pkgs.ripgrep}/bin/rg $out/lib/node_modules/@github/copilot/ripgrep/bin/linux-arm64/rg

    mkdir -p $out/bin
    makeBinaryWrapper ${pkgs.nodejs}/bin/node $out/bin/copilot \
      --add-flags "$out/lib/node_modules/@github/copilot/index.js" \
      --set SSL_CERT_DIR "${pkgs.cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    runHook postInstall
  '';
})
