{ pkgs }: {
  askGPT4 = pkgs.callPackage ./askGPT4/default.nix { };
  ptunn = pkgs.callPackage ./ptunn/default.nix { };
  udp2raw = pkgs.callPackage ./udp2raw/default.nix { };
  simc = pkgs.callPackage ./simc/default.nix { };
  local-garnet = (pkgs.callPackage ./garnet/default.nix { }).server;
  garnet-image = (pkgs.callPackage ./garnet/default.nix { }).image;
  myCopilot = pkgs.callPackage ./github-copilot-cli.nix { };
  ralph = pkgs.callPackage ./ralph.nix { };
  gac = pkgs.callPackage ./gac { };
}
