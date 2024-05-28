{ pkgs, ... }:
{
  home.packages = [
    (pkgs.nerdfonts.override { fonts = [ "CascadiaCode" ]; })
  ];

  fonts.fontconfig.enable = true;
}
