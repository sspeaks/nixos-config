{ pkgs, ... }:
{
  home.packages = [
    pkgs.nerd-fonts.caskaydia-mono
  ];

  fonts.fontconfig.enable = true;
}
