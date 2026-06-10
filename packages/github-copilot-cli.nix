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
  version = "1.0.61";

  sources = {
    "x86_64-linux" = {
      name = "github-copilot-${version}-linux-x64";
      hash = "sha256-n2J6KjWHRH56Oua/vOZVNnQYlwyJgBSy24IUlSTBD0g=";
    };
    "aarch64-linux" = {
      name = "github-copilot-${version}-linux-arm64";
      hash = "sha256-suU9SvFlNzzGpx6Gig//BV9ywy+5mz55OZcN18GSwpY=";
    };
    "x86_64-darwin" = {
      name = "github-copilot-${version}-darwin-x64";
      hash = "sha256-TbUiknDROHsNghD0uXfNwY4y7+j1szDgZ3gl/w2JCpE=";
    };
    "aarch64-darwin" = {
      name = "github-copilot-${version}-darwin-arm64";
      hash = "sha256-Lb4xfI2jwHZKSjsBgsMI5P74hV7gtZId6V31hGNYfxo=";
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
