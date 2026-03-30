{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
}:

let
  version = "1.0.13";

  sources = {
    "x86_64-linux" = {
      name = "copilot-linux-x64";
      hash = "sha256-3urOYZdwHidvqMzVMNqOWWGZhwFzpwHjKJ0dbMt26To=";
    };
    "aarch64-linux" = {
      name = "copilot-linux-arm64";
      hash = "sha256-/IsEiasd73et19UafdtcF2myeE4cfKLMvSwc0+c4pgs=";
    };
    "x86_64-darwin" = {
      name = "copilot-darwin-x64";
      hash = "sha256-ZHw5DWtL/oU/oKgOaIZyTqnrMXmJ8tNqzd9JXFb9874=";
    };
    "aarch64-darwin" = {
      name = "copilot-darwin-arm64";
      hash = "sha256-1HVKwwzwlye318DdN3wfsllBjeEgdZIhbZSBGojyoq0=";
    };
  };

  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "github-copilot-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/github/copilot-cli/releases/download/v${version}/${srcConfig.name}.tar.gz";
    inherit (srcConfig) hash;
  };

  nativeBuildInputs = [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  sourceRoot = ".";
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 copilot $out/libexec/copilot
    runHook postInstall
  '';

  postInstall = ''
    makeWrapper $out/libexec/copilot $out/bin/copilot \
      --add-flags "--no-auto-update"
  '';

  meta = {
    description = "GitHub Copilot CLI — coding agent in your terminal";
    homepage = "https://github.com/github/copilot-cli";
    license = lib.licenses.unfree;
    mainProgram = "copilot";
    platforms = builtins.attrNames sources;
  };
}
