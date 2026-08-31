{ lib
, stdenv
, fetchurl
, fetchFromGitHub
, autoPatchelfHook
, makeBinaryWrapper
, nodejs
, bash
, cacert
, glib
, libsecret
, gtk3
, webkitgtk_4_1
, cairo
, gdk-pixbuf
, libsoup_3
, wayland
, dbus
, xdotool
, ripgrep
}:

let
  version = "1.0.82";

  # Copilot's prebuilt WebView links to libxdo.so.3; nixpkgs xdotool 4 provides libxdo.so.4.
  xdotool_3 = xdotool.overrideAttrs (_: {
    version = "3.20211022.1";
    src = fetchFromGitHub {
      owner = "jordansissel";
      repo = "xdotool";
      rev = "v3.20211022.1";
      hash = "sha256-XFiaiHHtUSNFw+xhUR29+2RUHOa+Eyj1HHfjCUjwd9k=";
    };
  });

  sources = {
    "x86_64-linux" = {
      name = "github-copilot-${version}-linux-x64";
      hash = "sha256-pwmqluVRNxonZfK5PdbLoj8N05DvzAd7FYxt+2ftogs=";
    };
    "aarch64-linux" = {
      name = "github-copilot-${version}-linux-arm64";
      hash = "sha256-f8RroPcBVPfWGNyxBG7OgDvnPrL7SDbsoGcGD9RMnDE=";
    };
    "x86_64-darwin" = {
      name = "github-copilot-${version}-darwin-x64";
      hash = "sha256-Cl4oE9iMmLAm034Cj411DAz/vq8gA4Vhnm0frtae+fM=";
    };
    "aarch64-darwin" = {
      name = "github-copilot-${version}-darwin-arm64";
      hash = "sha256-8P7p9+7bLFEoombu1zoYfLtuoN/YHx9i4iu61/x9Pas=";
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
    gtk3
    webkitgtk_4_1
    cairo
    gdk-pixbuf
    libsoup_3
    wayland
    dbus
    xdotool_3
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
