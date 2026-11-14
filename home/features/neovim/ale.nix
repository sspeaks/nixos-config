{ pkgs, ... }:
{
  programs.nixvim = {
    extraConfigVim = ''
      let g:ale_linters = {'haskell': []}
    '';

    extraPlugins = with pkgs.vimPlugins; [ ale ];
  };
}
