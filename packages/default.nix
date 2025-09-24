{ pkgs }: {
  askGPT4 = pkgs.callPackage ./askGPT4/default.nix { };
  ptunn = pkgs.callPackage ./ptunn/default.nix { };
  udp2raw = pkgs.callPackage ./udp2raw/default.nix { };
  simc = pkgs.callPackage ./simc/default.nix { };
  garnet = (pkgs.callPackage ./garnet/default.nix { }).server;
}
