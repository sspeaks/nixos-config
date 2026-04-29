{ pkgs ? import <nixpkgs> { } }:
rec {
  server = pkgs.buildDotnetModule rec {
    pname = "garnet";
    version = "1.1.0";

    src = pkgs.fetchFromGitHub {
      owner = "microsoft";
      repo = "garnet";
      rev = "v${version}";
      hash = "sha256-EmwDc6kbOL++g1Xq4LoV3JuxYWSifOmv8vvWKsU3CE4=";
    };
    executables = [ "GarnetServer" ];
    projectFile = "main/GarnetServer/GarnetServer.csproj";
    nugetDeps = ./deps.json;

    dotnet-sdk = pkgs.dotnetCorePackages.sdk_9_0;
    dotnet-runtime = pkgs.dotnetCorePackages.runtime_9_0;
    dotnetBuildFlags = "-m:1";
    # Garnet multi-targets net8.0;net9.0 — restrict to net9.0 only
    # since we only provide the .NET 9.0 SDK/runtime.
    dotnetFlags = [ "-p:TargetFrameworks=net9.0" ];
    dotnetInstallFlags = [ "-f" "net9.0" ];

    meta = {
      description = "Microsoft Garnet — remote cache-store from Microsoft Research";
      homepage = "https://github.com/microsoft/garnet";
      license = pkgs.lib.licenses.mit;
      mainProgram = "GarnetServer";
      platforms = pkgs.lib.platforms.linux;
    };
  };
  image = pkgs.dockerTools.buildImage {
    name = "garnet-server";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "garnet-server-binaries";
      paths = [ server pkgs.redis ];
      pathsToLink = [ "/bin" ];
    };
    config = {
      Cmd = [ "GarnetServer" ];
      ExposedPorts = { "6379/tcp" = { }; };
    };
  };
}
