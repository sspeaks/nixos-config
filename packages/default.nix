{ pkgs
, system
}:

let
  isLinux = builtins.match ".*-linux" system != null;

  plateWrappers = pkgs.callPackage ./plate-wrappers/default.nix { };
  plateControls = pkgs.callPackage ./plate-controls/default.nix { };

  linuxPackages =
    if isLinux then {
      udp2raw = pkgs.callPackage ./udp2raw/default.nix { };
      simc = pkgs.callPackage ./simc/default.nix { };
      local-garnet = (pkgs.callPackage ./garnet/default.nix { }).server;
      garnet-image = (pkgs.callPackage ./garnet/default.nix { }).image;
      plate-wallpaper = pkgs.callPackage ./plate-wallpaper/default.nix { };
      inherit (plateWrappers) plate-dpms-on plate-dpms-off plate-logout;
      inherit (plateControls)
        plate-battery-status
        plate-brightness-get
        plate-brightness-set
        plate-brightness-step
        plate-volume-get
        plate-volume-set
        plate-volume-step
        plate-volume-toggle-mute
        plate-wifi-status
        plate-wifi-toggle
        plate-wifi-configure
        plate-bluetooth-status
        plate-bluetooth-toggle
        ;
    } else { };
in
{
  ptunn = pkgs.callPackage ./ptunn/default.nix { };
  myCopilot = pkgs.callPackage ./github-copilot-cli.nix { };
  squad-cli = pkgs.callPackage ./squad-cli { };
  gac = pkgs.callPackage ./gac { };
} // linuxPackages
