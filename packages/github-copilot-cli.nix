{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeBinaryWrapper
, nodejs
, bash
, cacert
, glib
, libsecret
, ripgrep
}:

let
  version = "1.0.60";

  sources = {
    "x86_64-linux" = {
      name = "github-copilot-${version}-linux-x64";
      hash = "sha256-Z8MmUY1apFA1OUEiJQrJQP3aHzosCLu3P2BjJFg1d3w=";
    };
    "aarch64-linux" = {
      name = "github-copilot-${version}-linux-arm64";
      hash = "sha256-sBG+bWOMgS7ucvrL2TztMMeNFI5sqcWfdwkOdb3D+xM=";
    };
    "x86_64-darwin" = {
      name = "github-copilot-${version}-darwin-x64";
      hash = "sha256-I5x8U0hofUIhbsE95swR5bT/+gIxBV/5wPKafcjS9Cg=";
    };
    "aarch64-darwin" = {
      name = "github-copilot-${version}-darwin-arm64";
      hash = "sha256-B7KEwVYBa3uBvy2QUPLUsfUGHP7SDgAgKPd/mmjaWiw=";
    };
  };

  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "github-copilot-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/github/copilot-cli/releases/download/v${version}/${srcConfig.name}.tgz";
    inherit (srcConfig) hash;
  };

  nativeBuildInputs = [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    glib
    libsecret
  ];

  sourceRoot = "package";
  dontStrip = true;

  autoPatchelfIgnoreMissingDeps = [
    "libX11.so.6"
    "libXtst.so.6"
    "libjpeg.so.8"
    "libpng16.so.16"
    "libpipewire-0.3.so.0"
    "libei.so.1"
  ];

  postPatch = ''
    (
      shopt -s globstar
      substituteInPlace **/*.js \
        --replace-quiet /bin/bash ${lib.getExe bash}
    )
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"/lib/github-copilot-cli
    cp -r * "$out"/lib/github-copilot-cli
    runHook postInstall
  '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    rm -rf "$out"/lib/github-copilot-cli/prebuilds/linuxmusl-*
  '';

  postInstall = ''
    makeWrapper ${nodejs}/bin/node "$out"/bin/copilot \
      --add-flag "$out"/lib/github-copilot-cli/index.js \
      --add-flag --no-auto-update \
      --set-default COPILOT_ALLOW_ALL true \
      --set USE_BUILTIN_RIPGREP false \
      --set-default NODE_NO_WARNINGS 1 \
      --set-default SSL_CERT_DIR ${cacert}/etc/ssl/certs \
      --prefix PATH : "${lib.makeBinPath [ bash ripgrep ]}"
  '';

  meta = {
    description = "GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal";
    homepage = "https://github.com/github/copilot-cli";
    changelog = "https://github.com/github/copilot-cli/releases/tag/v${version}";
    license = lib.licenses.unfree;
    mainProgram = "copilot";
    platforms = builtins.attrNames sources;
  };
}
