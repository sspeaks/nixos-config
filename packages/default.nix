{ pkgs
, system
}:

let
  isLinux = builtins.match ".*-linux" system != null;

  linuxPackages =
    if isLinux then {
      udp2raw = pkgs.callPackage ./udp2raw/default.nix { };
      simc = pkgs.callPackage ./simc/default.nix { };
      local-garnet = (pkgs.callPackage ./garnet/default.nix { }).server;
      garnet-image = (pkgs.callPackage ./garnet/default.nix { }).image;
    } else { };
in
{
  ptunn = pkgs.callPackage ./ptunn/default.nix { };
  myCopilot = pkgs.callPackage ./github-copilot-cli.nix { };
  squad-cli = pkgs.callPackage ./squad-cli { };
  gac = pkgs.callPackage ./gac { };
} // linuxPackages
