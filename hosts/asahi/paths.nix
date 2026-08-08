{ pkgs }:
let
  wallpaperPkg = pkgs.callPackage ../../packages/plate-wallpaper { };
in
{
  wallpaper = "${wallpaperPkg}/share/backgrounds/plate-xiv.png";
}
