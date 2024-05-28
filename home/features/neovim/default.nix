{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    extraConfig = ''
      " Full config: when writing or reading a buffer, and on changes in insert and
      " normal mode (after 500ms; no delay when writing).
      " call neomake#configure#automake('nrwi', 500)
      set mouse=
    '';
    plugins = with pkgs.vimPlugins; [
      # Syntax / Language Support ##########################
      ale
      vim-nix
    ];
  };
}
