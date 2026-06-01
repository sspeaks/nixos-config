{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeBinaryWrapper
, ripgrep
,
}:

let
  version = "1.0.57";

  sources = {
    "x86_64-linux" = {
      name = "copilot-linux-x64";
      hash = "sha256-0NDWS6JZ0Hznv+mhLL2aMNHfowvRogMjv36epxKpQPk=";
    };
    "aarch64-linux" = {
      name = "copilot-linux-arm64";
      hash = "sha256-4s0sXq3zO7uGpN56Rmhvh8jZzTkT6pctnakvcgd7Wy8=";
    };
    "x86_64-darwin" = {
      name = "copilot-darwin-x64";
      hash = "sha256-STgExE9B7n5RKDejP0eW0TRd9rhbvPOs3ucXrYfrQ40=";
    };
    "aarch64-darwin" = {
      name = "copilot-darwin-arm64";
      hash = "sha256-boPb1uDEc42eeEuJzR2wfstxE0m2b+zfktu9LU5t6bs=";
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
      --set-default COPILOT_ALLOW_ALL true \
      --set USE_BUILTIN_RIPGREP false \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
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
