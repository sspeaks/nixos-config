{ unstablePkgs, pkgs, lib, fetchurl, ... }:
let
  enable = false;
  eulaFile = builtins.toFile "eula.txt" ''
    # eula.txt managed by NixOS Configuration
    eula=true
  '';
  jvmOpts = "-Xms512M -Xmx512M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Djava.net.preferIPv4Stack=true ";
  dataDir = "/var/lib/minecraft";
  defaultServerPort = 25565;
in
lib.mkIf enable {
  nixpkgs.overlays = [
    (final: prev: {
      papermc =
        let
          version = "1.20.6";
          paperJar = prev.pkgs.fetchurl {
            url = "https://api.papermc.io/v2/projects/paper/versions/${version}/builds/97/downloads/paper-${version}-97.jar";
            sha256 = "sha256-1Lffv4j1/qMH1hCoMXnhBeswx4zTfqg5dC7JWD/aSm8=";
          };
        in
        (prev.papermc.override {
          jre = unstablePkgs.jdk21_headless;
        }).overrideAttrs (_: {
          inherit version;
          installPhase = ''
            install -Dm444 ${paperJar} $out/share/papermc/papermc.jar
            install -Dm555 -t $out/bin minecraft-server
          '';
        });
    })
  ];
  users.users.minecraft = {
    description = "Minecraft server service user";
    home = dataDir;
    createHome = true;
    isSystemUser = true;
    group = "minecraft";
  };
  users.groups.minecraft = { };
  systemd.services.minecraft-server = {
    enable = true;
    description = "Minecraft Server Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.screen}/bin/screen -DmS mc ${pkgs.papermc}/bin/minecraft-server ${jvmOpts}";
      Restart = "always";
      User = "minecraft";
      WorkingDirectory = dataDir;
    };
    preStart = ''
      ln -sf ${eulaFile} eula.txt
    '';
  };
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ defaultServerPort 25566 ];
    allowedTCPPorts = [ defaultServerPort 25566 ];
  };
}
