{ pkgs, ... }:
{
  programs.nixvim = {
    extraConfigVim = ''
      let g:ale_linters = {'haskell': []}
      " nvim's own LSP clients own LSP; ALE's duplicates them (e.g. a second rust-analyzer)
      let g:ale_disable_lsp = 1
    '';

    extraPlugins = with pkgs.vimPlugins; [ ale ];
  };
}
