{ pkgs, ... }:
{
  # Nerd Fonts the theme uses: JetBrains Mono for the desktop UI (see
  # theme/palette.nix `fonts.mono`), CaskaydiaCove (Cascadia Code, with
  # ligatures) for the terminal (`fonts.terminal`, consumed by
  # home/features/ghostty and alacritty).
  home.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.caskaydia-cove
  ];

  fonts.fontconfig.enable = true;
}
