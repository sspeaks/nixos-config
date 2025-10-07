{pkgs ? import <nixpkgs> {} }:
rec { 
  server = pkgs.buildDotnetModule rec {
        pname = "garnet";
        version = "1.0.84";

        src = pkgs.fetchFromGitHub {
          owner = "microsoft";
          repo = "garnet";
          rev = "v${version}";
          hash = "sha256-Bg+WQrGs9HyH3E9Ry4fPrnfDcKL8WuTH798pwHrLIuo=";
        };
        executables = [ "GarnetServer" ];
        projectFile = "main/GarnetServer/GarnetServer.csproj";
        nugetDeps = ./deps.json;

        dotnet-sdk = pkgs.dotnetCorePackages.sdk_9_0;
        dotnet-runtime = pkgs.dotnetCorePackages.runtime_9_0;
        dotnetBuildFlags = "-m:1";
        # preInstall = ''
        #   mv bin/Release/net9.0/linux-x64/{*.dll,*.pdb} bin/Release/net9.0/
        #   mv bin/Release/net8.0/linux-x64/{*.dll,*.pdb} bin/Release/net8.0/
        #   mv obj/Release/net9.0/linux-x64/{*.dll,*.pdb} bin/Release/net9.0/
        #   mv obj/Release/net8.0/linux-x64/{*.dll,*.pdb} bin/Release/net8.0/
        # '';
        dotnetInstallFlags = [ "-f" "net9.0"];

  };
  image = pkgs.dockerTools.buildImage {
    name = "garnet-server";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "garnet-server-binaries";
      paths = [ server ];
      pathsToLink = [ "/bin" ];
    };
    config = {
      Cmd = [ "GarnetServer" ];
      ExposedPorts = { "6379/tcp" = {}; };
    };
  };
}
