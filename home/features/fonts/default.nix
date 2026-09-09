{ pkgs, ... }:
{
  home.packages = [
    pkgs.nerd-fonts.iosevka # "Iosevka Nerd Font"
    pkgs.nerd-fonts.iosevka-term # "IosevkaTerm Nerd Font"
    # Still used by theme/palette.nix consumers, including Waybar and Alacritty.
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.caskaydia-cove
  ];

  fonts.fontconfig.enable = true;
}
