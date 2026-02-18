{ pkgs, fetchzip }:
let
  isAsahi = pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isLinux;
  rgPlatform = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-darwin" = "darwin-arm64";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "Unsupported platform for github-copilot-cli");
in
pkgs.github-copilot-cli.overrideAttrs (old: rec {
  version = "0.0.411";
  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-tZ/gt/C5w3m3m3wqyyIdOcF03BHnM/G/2c0UV0oQzEc=";
  };
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@github/copilot
    cp -r . $out/lib/node_modules/@github/copilot

    ${pkgs.lib.optionalString isAsahi ''
      # Replace bundled rg (statically links jemalloc built for 4K pages) with system ripgrep
      rm -rf $out/lib/node_modules/@github/copilot/ripgrep/bin
      mkdir -p $out/lib/node_modules/@github/copilot/ripgrep/bin/${rgPlatform}
      ln -s ${pkgs.ripgrep}/bin/rg $out/lib/node_modules/@github/copilot/ripgrep/bin/${rgPlatform}/rg
    ''}

    mkdir -p $out/bin
    makeBinaryWrapper ${pkgs.nodejs}/bin/node $out/bin/copilot \
      --add-flags "$out/lib/node_modules/@github/copilot/index.js" \
      --set SSL_CERT_DIR "${pkgs.cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    runHook postInstall
  '';
})
