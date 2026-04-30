{
  flake.nixosModules = {
    minecraft = ../modules/minecraft.nix;
    postgresql = ../modules/postgresql.nix;
    ptunnelServer = ../modules/ptunnelServer.nix;
    udp2rawServer = ../modules/udp2rawServer.nix;
    wireguard = ../modules/wireguard;
  };
}
