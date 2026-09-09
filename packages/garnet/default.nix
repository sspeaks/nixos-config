{ pkgs ? import <nixpkgs> { } }:
rec {
  server = pkgs.buildDotnetModule rec {
    pname = "garnet";
    version = "2.1.3";

    src = pkgs.fetchFromGitHub {
      owner = "microsoft";
      repo = "garnet";
      rev = "v${version}";
      hash = "sha256-2hFxb0lZj6jUgOVlYQj5z/RZDAqaa1MRvGwWsRsHnDQ=";
    };
    executables = [ "GarnetServer" ];
    projectFile = "main/GarnetServer/GarnetServer.csproj";
    nugetDeps = ./deps.json;

    dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
    dotnet-runtime = pkgs.dotnetCorePackages.runtime_10_0;
    dotnetBuildFlags = "-m:1";
    # Restrict multi-targeting to the SDK/runtime provided above.
    dotnetFlags = [ "-p:TargetFrameworks=net10.0" ];
    dotnetInstallFlags = [ "-f" "net10.0" ];

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
